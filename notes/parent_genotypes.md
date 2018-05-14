## Calculate allele frequencies
```bash
for chrom in $(ls data/genotype_2bit);do
    bin/infer_parent_genotypes.py infer -i data/genotype_2bit/$chrom --counts \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        -o output/allele_frequencies/parent_genotype_2bit/$chrom
done
```

## Infer parent genotypes 
```bash
for chrom in $(ls data/genotype_2bit);do
    bin/infer_parent_genotypes.py infer -i data/genotype_2bit/$chrom \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        -o data/parent_genotype_2bit/$chrom
done
genotype_files=$(for i in $(seq 10);do echo data/parent_genotype_2bit/chr${i};done)
bin/infer_parent_genotypes.py merge -i $genotype_files -o data/parent_genotype_2bit/all
rm $genotype_files
```
## Random projection
```bash
ranks="10000 20000 40000 80000"
for r in $ranks;do
    bin/random_projection.py transform -i data/parent_genotype_2bit/all \
        --datasets '*' \
        --components-file output/random_projection/2bit/components/${r}.npz \
        -o output/random_projection/parent_genotype/2bit/transformed/r=${r}
done
for r in $ranks;do
    bin/random_projection.py normalize \
        -i output/random_projection/parent_genotype/2bit/transformed/r=${r} \
        -o output/random_projection/parent_genotype/2bit/normalized/r=${r} \
        --scaler-file output/random_projection/2bit/scaler/r=${r}
done
bin/create_datasets.py merge_parent \
    -i data/parent_genotype_2bit/all \
    -o data/parent_genotype_2bit/all_matrix

```