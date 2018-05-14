## Filter features by one-way ANOVA p-values
```bash
awk '/^training/{print $2}' emaize_data/phenotype/pheno_emaize.txt > data/sample_names.training.txt
awk '/^test/{print $2}' emaize_data/phenotype/pheno_emaize.txt > data/sample_names.test.txt
n_fold=5
[ -d cv/sample_names ] || mkdir -p cv/sample_names
bin/create_cv_folds.py -i data/sample_names.training.txt -k $n_fold --prefix cv/sample_names/
{
for fold in $(seq $n_fold);do
    fold=$(($fold - 1))
    for i in $(seq 1 10);do
    echo "bin/filter_features.py -i data/genotype/chr${i} --phenotype-file emaize_data/phenotype/pheno_emaize.txt --sample-names-file cv/sample_names/${fold}.train.txt -o cv/anova.p_value/${fold}/chr${i}.h5"
    done
done
} > Jobs/filter_features.anova.txt
qsubgen -n filter_features.anova -a 1-20 --bsub -q Z-LU --task-file Jobs/filter_features.anova.txt
```
## Fast ANOVA applied to parent genotypes
```bash
bin/filter_features.py 2bit --genotype-file data/parent_genotype_2bit/all_matrix:X_female \
    --phenotype-file data/phenotypes/parent:female/trait1 \
    --indices-file tmp/parent_phenotypes_indices.h5:female \
    --metric anova \
    -o tmp/fast_anova.h5
```
## Apply fast ANOVA to minor allele frequencies
```bash

```