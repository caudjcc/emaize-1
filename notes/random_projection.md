## Separate the data matrix by samples (3-bit)
```bash
for sample_start in $(seq 0 500 6209);do
    bin/separate_genotype_by_sample.py -i data/genotype \
        --format binary \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        --sample-start $sample_start --sample-end $((sample_start + 500)) \
        -o data/genotype_by_sample
done
```

## Separate the data matrix by samples (2-bit)
```bash
for sample_start in $(seq 0 500 6209);do
    bin/separate_genotype_by_sample.py -i data/genotype_2bit \
        --format hdf5 \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        --sample-start $sample_start --sample-end $((sample_start + 500)) \
        -o data/genotype_2bit_by_sample
done
```

## Random projection on all features (3-bit, 5679357 features)
Set environment variables
```bash
ranks="10000 20000 40000 80000"
#ranks="120000 160000 200000"
# for 3-bit
n_features=5679357
code=""
genotype_by_sample_dir=data/genotype_by_sample
# for 2-bit
n_features=3786238
code="2bit/"
genotype_by_sample_dir=data/genotype_2bit_by_sample
```
Generate random projection matrices
```bash
{
for r in $ranks;do
    echo "bin/random_projection.py generate -p $n_features -r $r -o output/random_projection/${code}components/${r}.npz"
done
} > Jobs/random_projection_generate.txt
qsubgen -n random_projection_generate -q Z-LU -a 1-4 --bsub --task-file Jobs/random_projection_generate.txt
```
Transform the data matrix:
```bash
{
for r in $ranks;do
    for sample_group in $(ls data/genotype_by_sample);do
        echo "bin/random_projection.py transform -i ${genotype_by_sample_dir}/${sample_group}
--datasets '*'
--components-file output/random_projection/${code}components/${r}.npz
-o output/random_projection/${code}transformed/r=${r}/${sample_group}" | tr "\n" " "
        printf "\n"
    done
done
} > Jobs/random_projection_transform.txt
qsubgen -n random_projection_transform -q Z-LU -a 1-20 --bsub --task-file Jobs/random_projection_transform.txt
```

Merge transformed features of all samples into a single matrix:
```bash
for r in $ranks;do
    bin/create_datasets.py merge -i output/random_projection/transformed/r=${r}/* \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        -o output/random_projection/${code}transformed_matrix/r=${r}
done
```

Normalize the transformed features using z-scores:
```bash
for r in $ranks;do
    bin/create_datasets.py normalize -i output/random_projection/${code}transformed_matrix/r=${r} \
        -o output/random_projection/${code}normalized_matrix/r=${r} \
        --scaler-file output/random_projection/${code}scaler/r=${r}
done
```