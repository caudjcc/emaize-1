## Download data
* Download genome sequences from (ftp://ftp.ensemblgenomes.org/pub/release-25/plants/fasta/zea_mays/dna/Zea_mays.AGPv3.25.dna.genome.fa.gz). Saved to
`/Share/home/data/genomes/fasta/Zea_mays/AGPv3.25.fa`.
* Download annotations from  (ftp://ftp.ensemblgenomes.org/pub/release-25/plants/gff3/zea_mays/Zea_mays.AGPv3.25.gff3.gz). Saved to
`/Share/home/shibinbin/data/gtf/ensembl/Zea_mays.AGPv3.25/annotation.gff3`.
* Download emaize data from (https://www.jianguoyun.com/p/DZPT1A8Q5piuBhiEqSs#). Saved to
`/Share/home/shibinbin/data/emaize`.

## Convert genotype data to binary format (2-bit code, samples first)
```bash
[ -d data/genotype ] || mkdir -p data/genotype
head -n 1 emaize_data/genotype/chr1_emaize.genoMat \
    | tr '\t' '\n' | sed '1,4 d' > data/sample_names.txt
for i in $(seq 1 10);do
    cat emaize_data/genotype/chr${i}_emaize.genoMat | bin/genotype_to_corpus > data/genotype/chr${i}
done
```
The output file can be converted to a numpy array of shape (n_features, n_samples) with dtype = int8.

## Convert genotypes from 3-bit code
```bash
for chrom in $(ls data/genotype);do
    bin/convert_3bit_to_2bit.py -i data/genotype/$chrom \
        --phenotype-file emaize_data/phenotype/pheno_emaize.txt \
        -o data/genotype_2bit/$chrom
done
```
## Convert 2-bit code to minor allele copy numbers
```bash
for chrom in $(ls data/genotype);do
    bin/normalize_genotypes.py 2bit_to_minor -i data/genotype_2bit/${chrom}:data -o data/genotype_minor/$chrom
done
```
## Sample SNPs from the whole genome uniformly
```bash
for n_snps in 100 200 500 1000 10000 100000;do
    bin/preprocess.py random_select -i data/genotype_minor \
        --genomic-pos-file data/genomic_positions -n $n_snps -k 20 -o output/random_select/$n_snps
done
```
## Extract genomic positions of SNPs
```bash
bin/preprocess.py extract_snp_pos -i emaize_data/genotype -o data/genomic_positions
for n_snps in 1000 5000 10000 20000 40000 60000 80000 100000;do
    for i in 1 2 3;do
        bin/preprocess.py create_gsm -i data/genotype_minor \
            --genomic-pos-file data/genomic_positions -n $n_snps -o output/gsm/$n_snps/$i
    done
done
```
## Generate parent table from phenotype file
```bash
bin/preprocess.py generate_parent_table \
    -i emaize_data/phenotype/pheno_emaize.txt \
    -o data/parent_table
```
## Calculate genetic similarity matrix
```bash
for n_snps in 10000 100000;do
    for i in $(seq 3);do
        bin/preprocess.py create_gsm -i output/random_select/$n_snps:/$i/X \
            -o output/gsm/random_select/$n_snps/$i
    done
done
```
