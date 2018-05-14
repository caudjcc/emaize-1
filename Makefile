#ANACONDA_PATH = $(shell conda info --root)
ANACONDA_PATH = $(HOME)/apps/anaconda2
PYTHON_INCLUDE_PATH = $(ANACONDA_PATH)/include/python2.7
PYTHON_LIBRARY_PATH = $(ANACONDA_PATH)/lib
PYTHON_CC = gcc -shared -pthread -fPIC -fwrapv -O3 -Wall -fno-strict-aliasing -fopenmp  \
		-Wl,-rpath=$(PYTHON_LIBRARY_PATH),--no-as-needed \
		-I$(PYTHON_INCLUDE_PATH) -L$(PYTHON_LIBRARY_PATH) -lpython2.7
CYTHON = cython

all: bin/genotype_to_corpus build_ext

clean:
	rm -f bin/metric_regressor_grad.so
	rm -f src/metric_regressor_grad.c

bin/genotype_to_corpus: src/genotype_to_corpus.cpp
	g++ -O2 -g -o $@ src/genotype_to_corpus.cpp

bin/dump_corpus: src/dump_corpus.cpp
	g++ -O2 -g -o $@ src/dump_corpus

build_ext: bin/metric_regressor_grad.so

bin/metric_regressor_grad.so: src/metric_regressor_grad.c
	$(PYTHON_CC) -o $@ $<

src/metric_regressor_grad.c: src/metric_regressor_grad.pyx
	$(CYTHON) $<
