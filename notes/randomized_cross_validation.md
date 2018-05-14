###
```bash
bin/preprocess.py random_cv_split --n-datasets 100 \
    --train-index-file data/train_test_indices:train \
    --parent-table-file data/parent_table \
    -o output/randomized_cv/train_test_indices.s0
```
### Predict
```bash
feature_set=random_projection_80000
{
if [ "$feature_set" = "random_projection_10000" ];then
    input_args="--genotype-file output/random_projection/2bit/transformed_matrix/r=10000:X"
elif [ "$feature_set" = "random_projection_80000" ];then
    input_args="--genotype-file output/random_projection/2bit/transformed_matrix/r=80000:X"
elif [ "$feature_set" = "gsm_10000" ];then
    input_args="--gsm-file output/gsm/random_select/10000/1"
fi
for model_name in ridge gpr mlp;do
    for i in $(seq 0 99);do
        for trait in trait1 trait2 trait3;do
            echo bin/run_regression2.py $input_args \
                --phenotype-file data/phenotypes/all:${trait} \
                --train-index-file output/randomized_cv/train_test_indices.s0:/${i}/train \
                --test-index-file output/randomized_cv/train_test_indices.s0:/${i}/test \
                --model-name $model_name \
                -o output/randomized_cv/$feature_set/$model_name/$i/$trait
        done
    done
done
} > Jobs/randomized_cv.${feature_set}.txt
qsubgen -n randomized_cv.${feature_set} -q Z-LU -a 1-24 --bsub --task-file Jobs/randomized_cv.${feature_set}.txt
```