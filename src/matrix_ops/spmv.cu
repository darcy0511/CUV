#include <iostream>
#include <boost/any.hpp>
#include <host_dia_matrix.hpp>
#include <dev_dia_matrix.hpp>
#include "matrix_ops.hpp"
#include <texture.h>
#include <boost/preprocessor/arithmetic/inc.hpp>
#include <boost/preprocessor/cat.hpp>
#include <boost/preprocessor/repetition/repeat.hpp>
#include <boost/preprocessor/seq/for_each_product.hpp>
#include <boost/preprocessor/seq/to_tuple.hpp>


using namespace std;

// stuff from NVIDIA SDK
#define DIVIDE_INTO(x,y) ((x + y - 1)/y)
#define small_grid_thread_id(void) ((__umul24(blockDim.x, blockIdx.x) + threadIdx.x))
#define large_grid_thread_id(void) ((__umul24(blockDim.x,blockIdx.x + __umul24(blockIdx.y,gridDim.x)) + threadIdx.x))
#define large_grid_thread_num(void) ((__umul24(blockDim.x,gridDim.x + __umul24(blockDim.y,gridDim.y))))

#define MAX_NUM_IMGS_AT_ONCE 14
#define SEQ_ROW_FACT         1,2,4
#define SPMM_BLOCK_SIZE      256


namespace cuv{
	namespace spmv_impl{
		/*
		 *  For a given number of blocks, return a 2D grid large enough to contain them
		 *  FROM NVIDIA SDK
		 */
		dim3 make_large_grid(const unsigned int num_blocks){
			if (num_blocks <= 65535){
				return dim3(num_blocks);
			} else {
				unsigned int side = (unsigned int) ceil(sqrt((double)num_blocks));
				return dim3(side,side);
			}
		}

		dim3 make_large_grid(const unsigned int num_threads, const unsigned int blocksize){
			const unsigned int num_blocks = DIVIDE_INTO(num_threads, blocksize);
			if (num_blocks <= 65535){
				//fits in a 1D grid
				return dim3(num_blocks);
			} else {
				//2D grid is required
				const unsigned int side = (unsigned int) ceil(sqrt((double)num_blocks));
				return dim3(side,side);
			}
		}

// this file is generated using a perl-script from spmv_kernel.cuh
#include "spmv_kernel_inst.cuh"

		template <typename value_type, typename index_type>
			void spmv_dia_device(const dev_dia_matrix<value_type,index_type>& A, 
					const dev_vector<value_type>& v, 
					dev_vector<value_type>& dst, 
					char transA,
					const value_type& factAv,
					const value_type& factC)
			{
				const unsigned int toff = bind_x(v.ptr(), v.size());
				spmm_device_dispatch(A,v,dst,transA,factAv,factC,toff);
				cuvSafeCall(cudaThreadSynchronize());
				unbind_x(v.ptr());
			}

		/*template <bool transA, typename value_type, typename index_type>*/
		/*    void spmv_dia_tex_device(const dev_dia_matrix<value_type,index_type>& A, */
		/*            const dev_vector<value_type>& v, */
		/*            dev_vector<value_type>& dst)*/
		/*    {*/
		/*        const unsigned int BLOCK_SIZE = 256;*/
		/*        const dim3 grid = make_large_grid(A.h(),BLOCK_SIZE);*/

		/*        cuvAssert(A.num_dia() < BLOCK_SIZE); // kernel doesn't handle larger numbers of diagonals*/

		/*        bind_x(v.ptr());*/

		/*        if(!transA){*/
		/*            const unsigned int BLOCK_SIZE = 256;*/
		/*            const dim3 grid = make_large_grid(A.h(),BLOCK_SIZE);*/
		/*            cuvAssert(A.num_dia() < BLOCK_SIZE); // kernel doesn't handle larger numbers of diagonals*/
		/*            spmv_dia_kernel<value_type, index_type, BLOCK_SIZE, true> <<<grid, BLOCK_SIZE>>> (A.h(), A.w(),  A.num_dia(),  A.stride(), A.get_offsets().ptr(), A.vec().ptr(), v.ptr(), dst.ptr());*/
		/*        }else{*/
		/*            const unsigned int BLOCK_SIZE = 256;*/
		/*            const dim3 grid = make_large_grid(A.w(),BLOCK_SIZE);*/
		/*            cuvAssert(A.num_dia() < BLOCK_SIZE); // kernel doesn't handle larger numbers of diagonals*/
		/*            spmv_dia_kernel_trans<value_type, index_type, BLOCK_SIZE, true> <<<grid, BLOCK_SIZE>>> (A.h(), A.w(),  A.num_dia(),  A.stride(), A.get_offsets().ptr(), A.vec().ptr(), v.ptr(), dst.ptr());*/
		/*        }*/

		/*        unbind_x(v.ptr());*/
		/*    }*/
		template<class value_type, class index_type>
			void spmv(dev_vector<value_type,index_type>& dst, dev_dia_matrix<value_type,index_type>& A, dev_vector<value_type,index_type>& v, char transA, const float& factAv, const float& factC){
				// TODO: find a good assert
				/*if(transA=='t'){*/
					/*cuvAssert(A.w() == dst.size());*/
				/*}else{*/
					/*cuvAssert(A.h() == dst.size());*/
				/*}*/
				spmv_dia_device(A,v,dst,transA,factAv,factC);
			}


		/****************************************************************
		 *  Host Code
		 ****************************************************************/
		template<class value_type, class index_type>
			void spmv(host_vector<value_type,index_type>& dst, host_dia_matrix<value_type,index_type>& A, host_vector<value_type,index_type>& v, char transA, const float& factAv, const float& factC){
				const host_vector<int>& offsets = A.get_offsets();
				const int num_diags             = A.num_dia();
				const int A_h                   = A.h();
				const int A_w                   = A.w();
				const int A_stride              = A.stride();
				index_type max_dst = ((transA=='t') ? A_w : A_h);
				if(factC==0.f)
					for(int i=0;i<max_dst;i++) dst.set(i, 0);
				else
					for(int i=0;i<max_dst;i++) dst.set(i, dst[i] * factC);
				const int rf = A.row_fact();
				if(transA == 't'){
					cuvAssert(A_h == v.size());
					cuvAssert(A_w == dst.size());
					for(index_type i = 0; i < num_diags; i++){
						const int k = offsets[i];  //diagonal offset

						const index_type i_start =  1 * std::max((int)0, k);
						const index_type j_start = rf * std::max((int)0,-k); // the matrix is now _wider_ than high --> stretch columns!

						//number of elements to process
						const index_type N = std::min((A_h - j_start)/rf, A_w - i_start);

						const value_type * d_ = A.vec().ptr() + i*A_stride + j_start;
						const value_type * x_ = v.ptr() + j_start;
						value_type * y_ = dst.ptr() + i_start;

						for(index_type n = 0; n < N; n++,y_++){
							for(int k=0;k<rf;k++,x_++,d_++)
								*y_ += factAv * *d_ * *x_;
						}
					}
				}else{
					cuvAssert(A_w == v.size());
					cuvAssert(A_h == dst.size());
					for(index_type i = 0; i < num_diags; i++){
						const int k = offsets[i];  //diagonal offset

						const index_type i_start = rf*std::max((int)0,-k);
						const index_type j_start =  1*std::max((int)0, k);

						//number of elements to process
						const index_type N = std::min(A_h - i_start, rf*(A_w - j_start));

						const value_type * d_ = A.vec().ptr() + i*A_stride + i_start;
						const value_type * x_ = v.ptr() + j_start;
						value_type * y_ = dst.ptr() + i_start;

						for(index_type n = 0; n < N; n++){
							*y_++ += factAv * *d_++ * x_[n/rf];
						}
					}
				}
			}
	}

	template<>
		void prod(dense_matrix<float,column_major,host_memory_space>& dst,
				  host_dia_matrix<float>&                  A,
				  dense_matrix<float,column_major,host_memory_space>&   B,
				  char transA,
				  char transB,
				  const float& factAB,
				  const float& factC){
			cuvAssert(transB == 'n');
			cuvAssert(dst.w() == B.w());
			for(int i=0;i<dst.w();i++){
				host_vector<float> dst_v(dst.h(), dst.vec().ptr()+i*dst.h(), true);
				host_vector<float> src_v(B.h(),   B.vec().ptr()+i*B.h(), true);
				spmv(dst_v,A,src_v,transA,factAB,factC);
			}
		}
	template<>
		void prod(dense_matrix<float,column_major,dev_memory_space>& dst,
				  dev_dia_matrix<float>&                  A,
				  dense_matrix<float,column_major,dev_memory_space>&   B,
				  char transA,
				  char transB,
				  const float& factAB,
				  const float& factC){
			cuvAssert(transB == 'n');
			cuvAssert(dst.w() == B.w());
			cuvAssert(dst.vec_ptr());
			if(transA=='t'){
				cuvAssert(A.w() == dst.h());
			}else{
				cuvAssert(A.h() == dst.h());
			}
			const int num_at_same_time = min(MAX_NUM_IMGS_AT_ONCE, B.w());
			for(int i=0; i<dst.w(); i += num_at_same_time){
				dev_vector<float> dst_v(dst.h() * min(dst.w()-i,num_at_same_time), dst.vec().ptr()+i*dst.h(), true);
				dev_vector<float> src_v(B.h()   * min(B.w()-i,  num_at_same_time), B.vec().ptr()+i*B.h(), true);
				spmv(dst_v,A,src_v,transA,factAB,factC);
			}
		}
	template<class __matrix_type, class __vector_type>
		void spmv(__vector_type& dst, __matrix_type& A, __vector_type& v, char transA, const float& factAv, const float& factC){
			spmv_impl::spmv(dst,A,v,transA,factAv,factC);
		}
	template void spmv<host_dia_matrix<float>, host_vector<float> >(host_vector<float>&dst, host_dia_matrix<float>& A, host_vector<float>& v, char, const float&, const float&);
	template void spmv<dev_dia_matrix<float>, dev_vector<float> >(dev_vector<float>&dst, dev_dia_matrix<float>& A, dev_vector<float>& v, char, const float&, const float&);
}
