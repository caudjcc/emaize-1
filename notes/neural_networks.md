## MLP using bootstrapping
```bash
{
rank=10000
for batch_type in bycol byrow random diagonal;do
    for trait in trait1 trait2 trait3;do
        for i in $(seq 20);do
            echo "bin/run_regression.py -i output/random_projection/2bit/normalized_matrix/r=$rank -y y/$trait \
--phenotype-file emaize_data/phenotype/pheno_emaize.txt --max-epochs 20
--batch-type $batch_type
--model-name mlp
--bootstrap
-o output/mlp/r=$rank/$trait/batch_type=$batch_type/bootstrap/$i" | tr '\n' ' '
            printf '\n'
        done
    done
done
}  > Jobs/run_regression.cross_sampling.mlp.txt
qsubgen -n run_regression.cross_sampling.mlp -q Z-LU -a 1-40 --bsub --task-file Jobs/run_regression.cross_sampling.mlp.txt
```
## Gaussian process regressor
```bash
rank=10000
model_name=ridge
{
for trait in trait1 trait2 trait3;do
    for i in $(seq 20);do
        echo "bin/run_regression.py -i 'output/random_projection/2bit/normalized_matrix/r=$rank' -y 'y/$trait'
--phenotype-file emaize_data/phenotype/pheno_emaize.txt
--model-name $model_name -o output/$model_name/r=$rank/$trait/bootstrap/$i
--bootstrap" | tr '\n' ' '
        printf '\n'
    done
done
} > Jobs/run_regression.cross_sampling.${model_name}.txt
qsubgen -n run_regression.cross_sampling.${model_name} -q Z-LU -a 1-30 --bsub --task-file Jobs/run_regression.cross_sampling.${model_name}.txt
```

```bash
rank=10000
for trait in trait1 trait2 trait3;do
    bin/run_regression.py -i "output/random_projection/2bit/normalized_matrix/r=$rank" \
        -y y/$trait \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        --model-name mlp \
        --batch-type diagonal \
        -o output/mlp/r=$rank/$trait/final \
        --max-epochs 20
done
```