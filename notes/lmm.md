## Run FastLMM
```bash
bin/create_cv_folds.py -i emaize_data/phenotype/pheno_emaize.txt \
    --k-male 5 --k-female 20 --max-size 20 -m cross \
    -o output/fastlmm/cv_index.cross
bin/run_fastlmm.py single_snp --snp-file output/random_select/100000:0 \
    --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
    --k0-file output/random_select/10000:0 \
    --sample-indices-file output/fastlmm/cv_index.cross:/0/train \
    -o output/fastlmm

bin/run_fastlmm.py single_snp --snp-file tmp/random_select.10000:0 \
    --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
    --k0-file output/random_select/10000:0 \
    --sample-indices-file output/fastlmm/cv_index.cross:/0/train \
    -o tmp/fastlmm/single_snp

bin/run_fastlmm.py fastlmm --snp-file output/random_select/10000:1 \
    --k0-file output/random_select/10000:0 \
    --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
    --cvindex-file output/fastlmm/cv_index.cross:0 \
    --n-snps 1000 --penalty 1000 \
    -o output/fastlmm

%run -d -b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/lmm.py:525 bin/run_fastlmm.py fastlmm \
    --snp-file output/random_select/10000:1 \
    --k0-file output/random_select/10000:0 \
    --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
    --cvindex-file output/fastlmm/cv_index.cross:0 \
    --n-snps 1000 --penalty 1000.0 \
    -o output/fastlmm

%run -d -b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/lmm.py:531 bin/run_fastlmm.py fastlmm \
    --snp-file output/random_select/10000:1 \
    --k0-file output/random_select/10000:0 \
    --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
    --cvindex-file output/fastlmm/cv_index.cross:0 \
    --n-snps 1000 --penalty 1000.0 \
    -o output/fastlmm
b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/lmm.py:218
b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/lmm.py:529
b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/lmm.py:764
b /dev/shm/shibinbin/anaconda2/lib/python2.7/site-packages/fastlmm/inference/fastlmm_predictor.py:549
```
## Migrate files from IBM-E to local
```bash
remote_root=172.235.0.1:projects/emaize
for d in gsm random_select run_fastlmm mixed_model;do
    rsync -rav $remote_root/output/$d output/
done
rsync -rav $remote_root/emaize_data/phenotype emaize_data/
rsync -rav $remote_root/data/parent_table data/
rsync -rav $remote_root/data/genomic_positions data/
rsync -rav $remote_root/data/phenotypes data/
rsync -rav $remote_root/jupyter .
```

## Modify FastLMM code to add regularization to weights of fixed effects
* In function `fastlmm.inference.fastlmm_predictor.predict`
Add argument: `penalty=0.0`.
Add `penalty` argument to `LMM.findH2` and `lmm.nLLeval`:
```python
if h2raw is None:
    res = lmm.findH2(penalty=penalty) #!!!why is REML true in the return???
else:
    res = lmm.nLLeval(h2=h2raw, penalty=penalty)
```
* In function `fastlmm.inference.lmm.findH2`, remove `**kwargs`.
```python
def f(x,resmin=resmin):
```
## Predict using GSMs and get residuals
```bash
bin/create_cv_folds.py -i emaize_data/phenotype/pheno_emaize.txt \
    --k-male 5 --k-female 20 --max-size 20 -m cross \
    -o output/mixed_model/cv_index.cross
model_name=ridge
model_name=gpr
traits="trait1 trait2 trait3"
cvfolds=$(seq 0 9)
gsm_genotype_file=output/random_select/10000:/0/X
gsm_genotype_file=output/random_projection/2bit/normalized_matrix/r=10000:/X
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py single_model \
            --genotype-file $gsm_genotype_file \
            --phenotype-file data/phenotypes/all:${trait} \
            --parent-table-file data/parent_table \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --model-name $model_name --normalize-x --output-residuals \
            -o output/mixed_model/residuals/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Evaluate prediction using GSMs
```bash
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py evaluate \
            -i output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/residuals/$model_name/$trait/$cvfold/metrics.txt
    done
done
} | parallel -P 4
```
## Plot predictions using GSMs
```bash
for trait in $traits;do
    for cvfold in 0;do
        bin/run_mixed_model.py plot_predictions \
            -i output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions \
            --parent-table-file data/parent_table \
            --train-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --test-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions.pdf
    done
done
```
## Predict using GSMs and Ridge CV to get residuals
```bash
model_name=ridge_cv
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py single_model \
            --genotype-file $gsm_genotype_file \
            --phenotype-file data/phenotypes/all:${trait} \
            --parent-table-file data/parent_table \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --model-name $model_name --normalize-x --output-residuals \
            -o output/mixed_model/residuals/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Feature selection by ANOVA
```bash
genotype_file=output/random_select/100000:/1/X
genotype_file=data/genotype_minor/chr1:data
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/filter_features.py anova_linregress \
            --genotype-file $genotype_file \
            --phenotype-file output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions:residual \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --batch-size 100000 \
            -o output/mixed_model/anova_linregress/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Convert phenotypes to HDF5 format
```bash
bin/preprocess.py phenotypes_to_hdf5 -i emaize_data/phenotype/pheno_emaize.txt -o data/phenotypes/all
```
## Predict residuals
```bash
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py single_model \
            --genotype-file output/random_select/100000:/1/X \
            --parent-table-file data/parent_table \
            --phenotype-file output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions:residual \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --feature-indices-file output/mixed_model/anova_linregress/$model_name/$trait/${cvfold}:reject \
            --model-name ridge_cv --transpose-x --normalize-x \
            -o output/mixed_model/predict_residuals/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Evaluate prediction of residuals
```bash
for trait in trait1 trait2 trait3;do
    for cvfold in 0;do
        bin/run_mixed_model.py evaluate \
            -i output/mixed_model/predict_residuals/$model_name/$trait/$cvfold/predictions \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/predict_residuals/$model_name/$trait/$cvfold/metrics.txt
    done
done
```
## Predict phenotypes using mixed model
```bash
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py mixed_model \
            -a output/mixed_model/predict_residuals/$model_name/$trait/$cvfold/predictions \
            -b output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions \
            --phenotype-file data/phenotypes/all:${trait} \
            --parent-table-file data/parent_table \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --model-name linear \
            -o output/mixed_model/mixed_model/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Evaluate predictions of the mixed model
```bash
for trait in $traits;do
    for cvfold in $cvfolds;do
        bin/run_mixed_model.py evaluate \
            -i output/mixed_model/mixed_model/$model_name/$trait/$cvfold/predictions \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/mixed_model/$model_name/$trait/$cvfold/metrics.txt
    done
done
```
## Plot predictions of the mixed model
```bash
for trait in $traits;do
    for cvfold in $cvfolds;do
        bin/run_mixed_model.py plot_predictions \
            -i output/mixed_model/mixed_model/$model_name/$trait/$cvfold/predictions \
            --parent-table-file data/parent_table \
            --train-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --test-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/mixed_model/$model_name/$trait/$cvfold/predictions.pdf
    done
done
```

## Predict phenotypes using mixed model (with CV)
```bash
model_name=ridge
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py mixed_model \
            -a output/mixed_model/predict_residuals/$model_name/$trait/$cvfold/predictions \
            -b output/mixed_model/residuals/$model_name/$trait/$cvfold/predictions \
            --phenotype-file data/phenotypes/all:${trait} \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --parent-table-file data/parent_table \
            --model-name linear_cv \
            -o output/mixed_model/mixed_model_cv/$model_name/$trait/$cvfold
    done
done
} | parallel -P 4
```
## Evaluate predictions of the mixed model (with CV)
```bash
for trait in $traits;do
    for cvfold in $cvfolds;do
        bin/run_mixed_model.py evaluate \
            -i output/mixed_model/mixed_model_cv/$model_name/$trait/$cvfold/predictions \
            --sample-indices-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_model/mixed_model_cv/$model_name/$trait/$cvfold/metrics.txt
    done
done
```


## Mixed ridge using SNPs selected by FastLMM single_snp
First preprocess using `jupyter/fastlmm_single_snp_preprocess.ipynb`.

```bash
cvfolds=$(seq 6 19)
{
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py mixed_ridge \
            --genotype-file output/fastlmm_single_snp/4000/$cvfold/$trait:/X \
            --transpose-genotype \
            --gsm-file output/gsm/random_select/100000/1 \
            --phenotype-file data/phenotypes/all:$trait \
            --parent-table-file data/parent_table \
            --train-index-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --test-index-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_ridge/single_snp/$trait/$cvfold
     done
done
} > Jobs/mixed_ridge.txt
qsubgen -n mixed_ridge -q Z-LU -a 1-10 -j 5 --bsub --task-file Jobs/mixed_ridge.txt
```
## Mixed ridge on randomly selected SNPs
```bash
cvfolds=$(seq 0 19)
for trait in $traits;do
    for cvfold in $cvfolds;do
        echo bin/run_mixed_model.py mixed_ridge \
            --genotype-file output/random_select/200:/0/X \
            --transpose-genotype \
            --gsm-file output/gsm/random_select/100000/1 \
            --phenotype-file data/phenotypes/all:$trait \
            --parent-table-file data/parent_table \
            --train-index-file output/fastlmm/cv_index.cross:/$cvfold/train \
            --test-index-file output/fastlmm/cv_index.cross:/$cvfold/test \
            -o output/mixed_ridge/random_select_200/$trait/$cvfold
     done
done
```

## Mixed ridge on randomly selected SNPs (100, 200, 500)
```bash
snp_set_size=500
{
snp_sets=$(seq 0 99)
for trait in $traits;do
    for snp_set in $snp_sets;do
        for cv_type in s0 s1m s1f;do
            echo bin/run_mixed_model.py mixed_ridge \
                --genotype-file output/random_select/${snp_set_size}:/$snp_set/X \
                --transpose-genotype \
                --gsm-file output/gsm/random_select/100000/1 \
                --phenotype-file data/phenotypes/all:$trait \
                --parent-table-file data/parent_table \
                --train-index-file data/train_test_indices:/train \
                --test-index-file data/train_test_indices:/test \
                --cv-type $cv_type \
                -o output/mixed_ridge/random_select_${snp_set_size}/$trait/$snp_set/$cv_type
        done
    done
done
} > Jobs/mixed_ridge.random_select_${snp_set_size}.txt
qsubgen -n mixed_ridge.random_select_${snp_set_size} -q Z-LU -a 1-18 -j 5 --bsub --task-file Jobs/mixed_ridge.random_select_${snp_set_size}.txt
```
## Metric regression (linear projection) using randomly selected SNPs
```bash
snp_set=0
cv_type=s1f
snp_set_size=500
traits="trait1 trait2 trait3"
for trait in $traits;do
    echo bin/run_metric_regression.py metric_regressor \
                --genotype-file output/random_select/${snp_set_size}:/$snp_set/X \
                --transpose-genotype \
                -a 10.0 -q 100 --max-iter 20 --batch-size 10 --lr 0.5 --sparse-rate 0.5 \
                --gsm-file output/gsm/random_select/100000/1 \
                --phenotype-file data/phenotypes/all:$trait \
                --parent-table-file data/parent_table \
                --train-index-file data/train_test_indices:/train \
                --test-index-file data/train_test_indices:/test \
                --cv-type $cv_type \
                -o output/metric_regressor/random_select_${snp_set_size}/$trait/$snp_set/$cv_type
done
```
## Metric regression (linear ARD) using randomly selected SNPs
```bash
snp_set=0
cv_type=s1f
snp_set_size=1000
traits="trait1 trait2 trait3"
for trait in $traits;do
    bin/run_metric_regression.py metric_regressor \
                --genotype-file output/random_select/${snp_set_size}:/$snp_set/X \
                --transpose-genotype \
                -a 10.0 -q 100 --max-iter 20 --batch-size 50 --lr 0.2 --sparse-rate 1.0 \
                --gsm-file output/gsm/random_select/100000/1 \
                --phenotype-file data/phenotypes/all:$trait \
                --parent-table-file data/parent_table \
                --train-index-file data/train_test_indices:/train \
                --test-index-file data/train_test_indices:/test \
                --cv-type $cv_type \
                -o output/metric_regressor_linear_ard/random_select_${snp_set_size}/$trait/$snp_set/$cv_type
done

%run -d -b bin/models.py:441 bin/run_metric_regression.py metric_regressor \
    --genotype-file output/random_select/500:/0/X --transpose-genotype -a 10.0 -q 100 \
    --max-iter 20 --batch-size 10 --lr 0.1 --sparse-rate 1.0 \
    --gsm-file output/gsm/random_select/100000/1 --phenotype-file data/phenotypes/all:trait1 \
    --parent-table-file data/parent_table \
    --train-index-file data/train_test_indices:/train --test-index-file data/train_test_indices:/test \
    --cv-type s1f -o output/metric_regressor_linear_ard/random_select_500/trait1/0/s1f
```

## Mixed ridge on a subset of 10000 SNPs (random choice)
```bash
cv_type=s1f
traits="trait1 trait2 trait3"
{
for n_snps in 100 200 300;do
    for snp_set in $(seq 0 199);do
        for trait in $traits;do
            echo bin/run_mixed_model.py mixed_ridge \
                --genotype-file output/random_select/10000_choice_${n_snps}:/$snp_set/X \
                --transpose-genotype \
                --gsm-file output/gsm/random_select/100000/1 \
                --phenotype-file data/phenotypes/all:$trait \
                --parent-table-file data/parent_table \
                --train-index-file data/train_test_indices:/train \
                --test-index-file data/train_test_indices:/test \
                --cv-type $cv_type \
                --gammas 0.05 --alphas 0.001 -k 5 \
                -o output/mixed_ridge/10000_choice_${n_snps}/$trait/$snp_set/$cv_type
        done
    done
done
} > Jobs/mixed_ridge.10000_choice.txt
qsubgen -n mixed_ridge.10000_choice -q Z-LU -a 1-60 --bsub --task-file Jobs/mixed_ridge.10000_choice.txt
```
## Mixed ridge on a subset of 10000 SNPs (sequential select)
```bash
cv_type=s1f
traits="trait1 trait2 trait3"
{
for n_snps in 100 200;do
    max_snp_set=$((10000 / $n_snps - 1))
    for snp_set in $(seq 0 $max_snp_set);do
        for trait in $traits;do
            echo bin/run_mixed_model.py mixed_ridge \
                --genotype-file output/random_select/10000_seq_${n_snps}:/$snp_set/X \
                --transpose-genotype \
                --gsm-file output/gsm/random_select/100000/1 \
                --phenotype-file data/phenotypes/all:$trait \
                --parent-table-file data/parent_table \
                --train-index-file data/train_test_indices:/train \
                --test-index-file data/train_test_indices:/test \
                --cv-type $cv_type \
                --gammas 0.05 --alphas 0.001 -k 5 \
                -o output/mixed_ridge/10000_seq_${n_snps}/$trait/$snp_set/$cv_type
        done
    done
done
} > Jobs/mixed_ridge.10000_seq.txt
qsubgen -n mixed_ridge.10000_seq -q Z-HNODE -a 1-32 --bsub --task-file Jobs/mixed_ridge.10000_seq.txt
```
