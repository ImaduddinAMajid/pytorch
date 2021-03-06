/**
 * Copyright (c) 2016-present, Facebook, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "caffe2/core/context_gpu.h"
#include "caffe2/operators/relu_n_op.h"

namespace caffe2 {
namespace {
template <typename T>
__global__ void ReluNKernel(const int N, const T* X, T* Y, const T thres) {
  CUDA_1D_KERNEL_LOOP(i, N) {
    auto data = X[i];
    Y[i] = data > 0 ? (data > thres ? thres : data) : 0;
  }
}

template <typename T>
__global__ void ReluNGradientKernel(
    const int N,
    const T* Y,
    const T* dY,
    T* dX,
    const T thres) {
  CUDA_1D_KERNEL_LOOP(i, N) {
    auto data = Y[i];
    dX[i] = data > 0 ? (data >= thres ? 0 : dY[i]) : 0;
  }
}
} // namespace

template <>
bool ReluNOp<float, CUDAContext>::RunOnDevice() {
  auto& X = Input(0);
  auto* Y = Output(0);
  CAFFE_ENFORCE_GT(X.size(), 0);
  Y->ResizeLike(X);
  ReluNKernel<<<
      CAFFE_GET_BLOCKS(X.size()),
      CAFFE_CUDA_NUM_THREADS,
      0,
      context_.cuda_stream()>>>(
      X.size(), X.data<float>(), Y->mutable_data<float>(), n);
  return true;
}

template <>
bool ReluNGradientOp<float, CUDAContext>::RunOnDevice() {
  auto& Y = Input(0);
  auto& dY = Input(1);
  auto* dX = Output(0);
  CAFFE_ENFORCE_GT(Y.size(), 0);
  CAFFE_ENFORCE_EQ(dY.size(), Y.size());
  dX->ResizeLike(Y);
  ReluNGradientKernel<float>
      <<<CAFFE_GET_BLOCKS(Y.size()),
         CAFFE_CUDA_NUM_THREADS,
         0,
         context_.cuda_stream()>>>(
          Y.size(),
          Y.data<float>(),
          dY.data<float>(),
          dX->mutable_data<float>(),
          n);
  return true;
}

REGISTER_CUDA_OPERATOR(ReluN, ReluNOp<float, CUDAContext>);
REGISTER_CUDA_OPERATOR(ReluNGradient, ReluNGradientOp<float, CUDAContext>);
} // namespace caffe2
