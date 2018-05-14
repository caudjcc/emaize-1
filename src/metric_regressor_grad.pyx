import numpy as np
cimport numpy as np
cimport cython
from cython.parallel import prange
from cython.parallel cimport parallel
cimport openmp

@cython.boundscheck(False) # turn off bounds-checking for entire function
@cython.wraparound(False)  # turn off negative index wrapping for entire function
def compute_mse_grad_linear_ard(np.ndarray[np.float64_t, ndim=1] w,
        np.ndarray[np.float64_t, ndim=2] X1,
        np.ndarray[np.float64_t, ndim=2] X2,
        np.ndarray[np.float64_t, ndim=2] Kinv1,
        np.ndarray[np.float64_t, ndim=2] K2,
        np.ndarray[np.float64_t, ndim=2] a,
        np.ndarray[np.float64_t, ndim=2] err,
        np.ndarray[np.float64_t, ndim=2] mask=None):
    '''Compute the gradients of MSE on the test samples with respect to relevance vector w.
    :param w: 1D array of shape [n_features]
    :return: gradients of MSE wrt. 2, 1D array of shape [n_features]
    '''
    cdef np.int64_t N1, N2, p
    cdef np.int64_t k, i, j, m
    N1 = X1.shape[0]
    N2 = X2.shape[0]
    p = X2.shape[1]

    cdef np.ndarray[np.float64_t, ndim=2] K2Kinv1 = K2.dot(Kinv1)
    cdef np.ndarray[np.float64_t, ndim=1] mse_grad = np.zeros_like(w)
    
    #cdef np.ndarray[np.float64_t, ndim=3] K1_grad = np.zeros((p, N1, N1), dtype=np.float64)
    #cdef np.ndarray[np.float64_t, ndim=3] K2_grad = np.zeros((p, N2, N1), dtype=np.float64)
    #cdef np.ndarray[np.float64_t, ndim=3] K_grad =  np.zeros((p, N2, N1), dtype=np.float64)
    cdef np.int64_t max_n_threads = openmp.omp_get_max_threads()
    cdef np.ndarray[np.float64_t, ndim=3] K1_grad = np.zeros((max_n_threads, N1, N1), dtype=np.float64)
    cdef np.ndarray[np.float64_t, ndim=3] K2_grad = np.zeros((max_n_threads, N2, N1), dtype=np.float64)
    cdef np.ndarray[np.float64_t, ndim=3] K_grad  = np.zeros((max_n_threads, N1, N1), dtype=np.float64)
    
    cdef np.int64_t thread_id
    with nogil, parallel():
        for k in prange(p):
            thread_id = openmp.omp_get_thread_num()
            # compute K1_grad
            for i in range(N1):
                for j in range(N1):
                    K1_grad[thread_id, i, j] = 2.0*w[k]*X1[i, k]*X1[j, k]
            # compute K2_grad
            for i in range(N2):
                for j in range(N1):
                    K2_grad[thread_id, i, j] = 2.0*w[k]*X2[i, k]*X1[j, k]
            # compute K_grad
            for i in range(N2):
                for j in range(N1):
                    K_grad[thread_id, i, j] = K2_grad[thread_id, i, j]
                    for m in range(N1):
                        K_grad[thread_id, i, j] += K2Kinv1[i, m]*K1_grad[thread_id, m, j]
            # compute mse_grad
            for i in range(N2):
                for j in range(N1):
                    mse_grad[k] += err[i, 0]*K_grad[thread_id, i, j]*a[j, 0]
    return mse_grad, K_grad

@cython.boundscheck(False) # turn off bounds-checking for entire function
@cython.wraparound(False)  # turn off negative index wrapping for entire function
def compute_mse_grad_linear(np.ndarray[np.float64_t, ndim=2] A,
        np.ndarray[np.float64_t, ndim=2] X1,
        np.ndarray[np.float64_t, ndim=2] X2,
        np.ndarray[np.float64_t, ndim=2] Kinv1,
        np.ndarray[np.float64_t, ndim=2] K2,
        np.ndarray[np.float64_t, ndim=2] a,
        np.ndarray[np.float64_t, ndim=2] err,
        np.ndarray[np.int32_t, ndim=2] mask=None):
    '''Compute the gradients of MSE on the test samples with respect to the transformation matrix A
    :param A: 2D array of shape [n_hidden, n_features]
    :param X1: 2D array of shape [n_samples1, n_features]
    :param X2: 2D array of shape [n_samples2, n_features]
    :param Kinv1: K1^{-1}, 2D array of shape [n_samples1, n_samples1]
    :param K2: X2.dot(X1.T), 2D array of shape [n_samples2, n_samples2]
    :param a: K1^{-1}y, 2D array of shape [n_samples1, 1]
    :param err: y2 - \hat{y2}, 2D array of shape [n_samples2, 1]
    :param mask: mask array for A, 2D array of shape [n_hidden, n_features]
    :return: gradients of MSE wrt. A, 2D array of shape [n_hidden, n_features]
    '''
    cdef np.int64_t N1, N2, p, q
    cdef np.int64_t k, l, i, j, m
    N1 = X1.shape[0]
    N2 = X2.shape[0]
    p = X1.shape[1]
    q = A.shape[0]

    #cdef np.ndarray[np.float64_t, ndim=2] K1_grad = np.zeros((N1, N1), dtype=np.float64)
    #cdef np.ndarray[np.float64_t, ndim=2] K2_grad = np.zeros((N2, N1), dtype=np.float64)
    #cdef np.ndarray[np.float64_t, ndim=2] K_grad = np.zeros((N2, N1), dtype=np.float64)
    cdef np.ndarray[np.float64_t, ndim=2] K2Kinv1 = K2.dot(Kinv1)
    cdef np.ndarray[np.float64_t, ndim=2] mse_grad = np.zeros_like(A)
    
    cdef np.ndarray[np.float64_t, ndim=3] K1_grad = np.zeros((q, N1, N1), dtype=np.float64)
    cdef np.ndarray[np.float64_t, ndim=3] K2_grad = np.zeros((q, N2, N1), dtype=np.float64)
    cdef np.ndarray[np.float64_t, ndim=3] K_grad =  np.zeros((q, N2, N1), dtype=np.float64)
   
    with nogil, parallel():
        for k in prange(q, schedule='guided'):
            for l in range(p):
                if (mask is not None) and (mask[k, l] == 0):
                    continue
                # compute K1_grad
                for i in range(N1):
                    for j in range(N1):
                        K1_grad[k, i, j] = 0.0
                        if i <= j:
                            for m in range(p):
                                K1_grad[k, i, j] += A[k, m] * (X1[i, m] * X1[j, l] + X1[j, m] * X1[i, l])
                        else:
                            K1_grad[k, i, j] = K1_grad[k, j, i]
                # compute K2_grad
                for i in range(N2):
                    for j in range(N1):
                        K2_grad[k, i, j] = 0.0
                        for m in range(p):
                            K2_grad[k, i, j] += A[k, m] * (X2[i, m] * X1[j, l] + X1[j, m] * X2[i, l])
                # compute K_grad
                for i in range(N2):
                    for j in range(N1):
                        K_grad[k, i, j] = K2_grad[k, i, j]
                        for m in range(N1):
                            K_grad[k, i, j] += K2Kinv1[i, m]*K1_grad[k, m, j]
                # compute mse_grad
                for i in range(N2):
                    for j in range(N1):
                        mse_grad[k, l] += err[i, 0]*K_grad[k, i, j]*a[j, 0]
                #mse_grad[k, l] = err.T.dot((K2_grad + K2Kinv1.dot(K1_grad)).dot(a))
    return mse_grad
