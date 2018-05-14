## Installation
The programs are mostly written in Python, except for a few C++ and Cython code.

It is recommended to install Anaconda (version 4.4.0, can be downloaded from
 (https://repo.continuum.io/archive/Anaconda2-4.4.0-Linux-x86_64.sh)) and the following Python packages:
```bash
pip install h5py tqdm
```

Only one C++ program `genotype_to_corpus` needs to be compiled:
```bash
make
```
and the program binary will be generated in `bin/genotype_to_corpus`.

The Python scripts are in the `bin/` directory.

## Instructions
### Input files
Assume that the input raw data is in a directory named `emaize_data`, and the directory structure is like:
```
emaize_data/
├── genotype
│   ├── chr10_emaize.genoMat
│   ├── chr1_emaize.genoMat
│   ├── chr2_emaize.genoMat
│   ├── chr3_emaize.genoMat
│   ├── chr4_emaize.genoMat
│   ├── chr5_emaize.genoMat
│   ├── chr6_emaize.genoMat
│   ├── chr7_emaize.genoMat
│   ├── chr8_emaize.genoMat
│   └── chr9_emaize.genoMat
├── phenotype
│   ├── pheno_emaize.txt
│   └── phenotype_fm_table.txt
└── README_eMaize_data_eng.pdf
```
The first 4 lines of `emaize_data/genotype` is like:
```
snp     alleles chrom   posi    L0001   L0002   L0003   L0004   L0005   L0006   L0007   L0008   L0009   L0010
chr1.s_5402     A/T     1       5402    AA      AA      AA      AT      AA      AA      AA      AA      AA
chr1.s_6490     A/G     1       6490    AA      AA      AA      AA      AA      AA      AA      AA      AA
chr1.s_6707     T/G     1       6707    TT      TT      TT      TG      TT      TT      TT      TT      TT
```
### Extract the sample names
```bash
[ -d data ] || mkdir data
head -n 1 emaize_data/genotype/chr1_emaize.genoMat \
    | tr '\t' '\n' | sed '1,4 d' > data/sample_names.txt
```
### Convert genotype data to binary format (3-bit code, samples first)
Assume that a genotype has two alleles: A and B, then a genotype is converted to 3-bit code
following the rules: AA -> 100, AB -> 010, BB -> 001.
```bash
[ -d data/genotype ] || mkdir -p data/genotype
for i in $(seq 1 10);do
    cat emaize_data/genotype/chr${i}_emaize.genoMat | bin/genotype_to_corpus > data/genotype/chr${i}
done
```
This will create a directory `data/genotype`,
and generate a binary file named `data/genotype/$chrom` for each chromosome.
Each output file `data/genotype/$chrom` is the dump of a 2D C array of shape (n_features*3, n_samples) with dtype = int8.

### Convert genotypes from 3-bit code to 2-bit code
Assume that a genotype has two alleles: A and B, then a genotype is converted to 2-bit code
following the rules: AA -> 10, AB -> 11, BB -> 01.
```bash
for chrom in $(ls data/genotype);do
    bin/convert_3bit_to_2bit.py -i data/genotype/$chrom \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        -o data/genotype_2bit/$chrom
done
```
This will create a directory `data/genotype_2bit`, and generate an output file `data/genotype_2bit/$chrom` for each chromosome.
Each output file `data/genotype_2bit/$chrom` is in HDF5 format.

### Convert 2-bit code to minor allele copy numbers
Assume that a genotype has a major allele A and a minor allele B, then a genotype is converted to an integer
using the copy number of the major allele: AA -> 2, AB -> 1, BB -> 0. An allele is considered as major allele if
the frequency of the allele frequency among all samples is larger than 50%.
```bash
for chrom in $(ls data/genotype);do
    bin/normalize_genotypes.py 2bit_to_minor -i data/genotype_2bit/${chrom}:data -o data/genotype_minor/$chrom
done
```
This will create a directory `data/genotype_minor`, and generate an output file `data/genotype_minor/$chrom` for each chromosome.
Each output file `data/genotype_2bit/$chrom` is in HDF5 format.

### Extract genomic positions of selected SNPs
```bash
bin/preprocess.py extract_snp_pos -i emaize_data/genotype -o data/genomic_positions
```
This will create an output file `data/genomic_positions`.

### Sample SNPs from the whole genome uniformly (10000, 100000)
```bash
for n_snps in 10000 100000;do
    bin/preprocess.py random_select -i data/genotype_minor \
        --genomic-pos-file data/genomic_positions -n $n_snps -k 1 -o output/random_select/$n_snps
done
```
This will create two files `output/random_select/10000` and `output/random_select/100000`.
Each output file is an HDF5 file with k groups and each group contains 3 datasets:
`/$group/X`, `/$group/chrom`, `/$group/positions`.

### Calculate genetic similarity matrix
```bash
bin/preprocess.py create_gsm -i output/random_select/100000:/0/X \
            -o output/gsm/random_select/100000/0
```
This will create an output file `output/gsm/random_select/100000/0`.
Each output file contains 4 datasets:
K (genetic similarity matrix), U, S, V (result of SVD on K).

### Generate parent table from phenotype file
```bash
bin/preprocess.py generate_parent_table \
    -i emaize_data/phenotype/pheno_emaize.txt \
    -o data/parent_table
```
This will create an output file `data/parent_table`, which contains one dataset `data`.
The dataset is a matrix with 30 rows (male parents) and 207 columns (female parents).

### Convert phenotypes from plain text to HDF5 format
Assume that the phenotypes are in file `emaize_data/phenotype/pheno_emaize.txt` with the first few lines:
```
type	id	pedigree	trait1	trait2	trait3
training	L0001	f1_X_m1	-1.74610282478836	-0.785525121573821	-0.331636965445395
training	L0002	f2_X_m1	-1.67924837319023	-1.5694898694515	-2.57261413504835
training	L0003	f3_X_m1	-2.74891959876045	-0.608643883224438	-1.10881183080429
training	L0004	f4_X_m1	-2.41464734076976	-0.672045141494308	-1.31505078714756
training	L0005	f5_X_m1	-1.87981172798464	-0.740912762992952	-1.87918131205325
```
Run the following command to convert the table to HDF5 formatL
```bash
bin/preprocess.py phenotypes_to_hdf5 -i emaize_data/phenotype/pheno_emaize.txt \
    -o data/phenotypes/all
```
This will create an output file `data/phenotypes/all` in HDF5 format with 6 datasets that correpond to the 6 columns in the file.

### Convert training and test indices to HDF5 format
Read the phenotype file `emaize_data/phenotype/pheno_emaize.txt` and extract the sample indices with
the 'type' column specified as 'training' or 'test'.
```bash
bin/preprocess.py phenotypes_to_train_test_indices -i emaize_data/phenotype/pheno_emaize.txt \
    -o data/train_test_indices
```
This will create an output file `data/train_test_indices` that contains two datasets: train, test.

### Select a subset (200 or 300 SNPs) from 10000 SNPs
```bash
for n_snps in 100 200 300;do
    bin/preprocess.py random_select_subset -i output/random_select/10000:/0 \
        -m random_choice -n $n_snps --n-groups 200 -o output/random_select_subset/10000/random_choice/${n_snps}
done
```
This will create an output file `output/random_select_subset/10000/random_choice/${n_snps}` for each SNP set size.

## Training and test
### Convert sample indices of training set and test set to HDF5 format
First prepare two text files named `$train_index_file` and `$test_index_file` that contain
the indices of the training and test samples, one per line. And run:
```bash
bin/preprocess.py convert_train_test_indices \
    --train-index-file $train_index_file \
    --test-index-file $test_index_file \
    -o output/train_test_indices/0
```
This will create an output file `output/train_test_indices/0` in HDF5 format with two datasets: train, test.

### Mixed ridge on a subset of 10000 SNPs (random choice)
```bash
traits="trait1 trait2 trait3"
cv_type=s1f
for gamma in 0.05 0.10 0.15 0.20;do
    for n_snps in 200 300;do
        for snp_set in $(seq 0 199);do
            for trait in $traits;do
                bin/run_mixed_model.py mixed_ridge \
                    --genotype-file output/random_select_subset/10000/random_choice/${n_snps}:/$snp_set/X \
                    --transpose-genotype \
                    --gsm-file output/gsm/random_select/100000/0 \
                    --phenotype-file data/phenotypes/all:$trait \
                    --parent-table-file data/parent_table \
                    --train-index-file data/train_test_indices:/train \
                    --test-index-file data/train_test_indices:/test \
                    --cv-type $cv_type \
                    --gammas $gamma --alphas 0.001 \
                    -o output/mixed_ridge/10000/random_choice/gamma=${gamma}/${n_snps}/$trait/$snp_set/$cv_type
            done
        done
    done
done
```
### Select best subset of SNPs based on CV MSE
```bash
traits="trait1 trait2 trait3"
for trait in $traits;do
    bin/run_mixed_model.py select_best_subset \
        -i output/mixed_ridge/10000/random_choice \
        --genotype-dir --genotype-file output/random_select_subset/10000/random_choice \
        --test-index-file data/train_test_indices:/test \
        --gammas 0.05,0.10,0.15,0.20 --n-snps 200,300 --n-groups 200 \
        --by mse_cv_mean --traits $trait \
        -o output/select_best_subset/10000/random_choice
done
```
This will generate two summary tables:
* `output/select_best_subset/10000/summary.txt`: cross-validation results of all parameter combinations and SNP subsets.
* `output/select_best_subset/10000/summary_best.txt`: results of best SNP subsets that are selected with cross-validation.
Each line is a combination of SNP subset and parameter combination.
The script will also generate the best predictions on the test samples: `output/select_best_subset/10000/${trait}.${rank}.txt`.

## Reproduce the final predictions
Several files are required to reproduce the final predictions:
* `best_subsets/snps`: selected SNP subsets.
* `output/gsm/random_select/100000/1`: genetic similarity matrix and results of SVD.
* `data/phenotypes/all`: phenotypes of the training samples.
* `data/parent_table`: a 2D table with rows as male parents and columns as female parents.
* `data/train_test_indices`: indices of training samples and test samples.
Run
```bash
./bin/reproduce_final_predictions.sh
```
This will create a text file `best_subsets/predictions.txt`.