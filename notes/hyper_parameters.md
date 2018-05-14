## Fix hyperopt-mongo module
Replace `import six.moves.cPickle as pickle` with `import dill as pickle` in file `hyperopt/fmin.py` and `hyperopt/mongoexp.py`.

## Test hyperopt-sklearn wrapper
```bash
bin/hyperopt_search.py -i "tmp/r=10000" --index-file tmp/indices -x X -y y/trait1 \
    --mongo "mongo://127.0.0.1:27017/hyperopt/jobs" --regressor knn_regression -o tmp/hyperopt_search
bin/hyperopt_search.py -i "tmp/r=10000" --index-file tmp/indices -x X -y y/trait1 \
    --regressor knn_regression -o tmp/hyperopt_search
```