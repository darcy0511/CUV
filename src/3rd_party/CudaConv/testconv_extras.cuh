//*LB*
// Copyright (c) 2009, Alexander Krizhevsky
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
//  * Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//  * Neither the name of the University of Toronto 
//    nor the names of its contributors may be used to endorse or promote
//    products derived from this software without specific prior written
//    permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//*LE*





/*
 * testconv_extras.cuh
 *
 *  Created on: Nov 10, 2009
 *      Author: Alex Krizhevsky (akrizhevsky@gmail.com)
 */

#ifndef TESTCONV_EXTRAS_CUH_
#define TESTCONV_EXTRAS_CUH_
#include <cutil_inline.h>
#include <matrix.h>
#include <nvmatrix.cuh>
#include "conv_extras.cuh"

void test_conv_bw_fit_dyn_2per(int boardNum);
void test_conv_bw_nofit_dyn_1per(int imgSize, int filterSize, int threadsY, int threadsX, int boardNum);
void test_conv_bw_nofit_dyn_2per(int imgSize, int filterSize, int threadsY, int threadsX, int boardNum);
void test_conv_bw_nofit_4x16_dynfilter_2per(int imgSize, int filterSize, int filterCacheY, int filterCacheX, int boardNum);

#endif /* TESTCONV_EXTRAS_CUH_ */
