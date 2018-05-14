# Dimension reduction using SVD

## Install the *gensim* Python package
Refer to the official website: (https://radimrehurek.com/gensim).
```bash
pip install gensim
pip install Pyro4
```
## Create a dictionary that maps SNP IDs to integers
```bash
ln -s -f /Share/home/shibinbin/data/emaize emaize_data
[ -d lsi_model ] || mkdir lsi_model
{
for i in $(seq 1 10);do
    zcat emaize_data/genotype/chr${i}_emaize.genoMat.gz \
    | awk 'NR>1{split($2, a, "/");print $1 "|" a[1] a[1];print $1 "|" a[1] a[2];print $1 "|" a[2] a[2]}'
done
} | awk 'BEGIN{OFS="\t"}{print NR,$1}' > lsi_model/id_to_name.txt
```
## Convert genotype data to corpus (Market Matrix format)
```bash
[ -d data/genotype ] || mkdir -p data/genotype
head -n 1 emaize_data/genotype/chr1_emaize.genoMat \
    | tr '\t' '\n' | sed '1,4 d' > data/sample_names.txt
for i in $(seq 1 10);do
    cat emaize_data/genotype/chr${i}_emaize.genoMat | bin/genotype_to_corpus > data/genotype/chr${i}
done
```

## Run the LsiModel
```bash
bin/start-lsi-cluster.sh start_naming
bin/start-lsi-cluster.sh start_workers
bin/start-lsi-cluster.sh start_dispatcher

job_name=lsi_model.chr1 bin/start-lsi-cluster.sh submit_job \
    bin/run_lsi.py \
    --genotype data/genotype/chr1 \
    --phenotype emaize_data/phenotype/pheno_emaize.txt \
    --sample-names-file data/sample_names.txt \
    --model-file models/lsi_model/chr1 \
    --rank 5000
```