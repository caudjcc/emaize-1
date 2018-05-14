# Annotate the SNPs with genomic information

## Download data
* Download genome sequences from (ftp://ftp.ensemblgenomes.org/pub/release-25/plants/fasta/zea_mays/dna/Zea_mays.AGPv3.25.dna.genome.fa.gz). Saved to
`/Share/home/data/genomes/fasta/Zea_mays/AGPv3.25.fa`.
* Download annotations from  (ftp://ftp.ensemblgenomes.org/pub/release-25/plants/gff3/zea_mays/Zea_mays.AGPv3.25.gff3.gz). Saved to
`/Share/home/shibinbin/data/gtf/ensembl/Zea_mays.AGPv3.25/annotation.gff3`.
* Download emaize data from (https://www.jianguoyun.com/p/DZPT1A8Q5piuBhiEqSs#). Saved to
`/Share/home/shibinbin/data/emaize`.

## Preprocessing

### Fix the GFF file
remove "transcript:" and "CDS:" from the ID attribute)
```bash
sed -e 's/transcript://' -e 's/CDS://' annotation.gff3 \
    | awk 'BEGIN{OFS="\t"} $3 != "repeat_region"' > annotation.fixed.gff3
```
### Only keep chromosome sequences (chr1-10)
```bash
grep -E '^#|^[0-9]+'$'\t' annotation.fixed.gff3 > annotation.chromosome.gff3
```
### Convert GFF3 format to GenePred format (using UCSC tools)
```bash
gff3ToGenePred annotation.chromosome.gff3 annotation.chromosome.gp
annotation.chromosome.gp
```
This will generate a file with 15 columns (defined in the `readUCSCGeneAnnotation` function in `annotate_variation.pl` in the ANNOVAR package):
* name
* chr
* dbstrand
* txstart
* txend
* cdsstart
* cdsend
* exoncount
* exonstart
* exonend
* id
* name2
* cdsstartstat
* cdsendstat
* exonframes

### Build a FASTA index
```bash
samtools faidx AGPv3.25.fa
```
### Generate a chromosome sizes file
```bash
cut -d$'\t' -f1,2 AGPv3.25.fa.fai > /Share/home/shibinbin/data/chrom_sizes/Zea_mays.AGPv3.25.genome
```
### Extract the FASTA sequences from spliced transcripts
```bash
gffread -g AGPv3.25.fa \
    -s /Share/home/shibinbin/data/chrom_sizes/Zea_mays.AGPv3.25.genome \
    -W -M -F -G -A -O -E -w AGPv3.25.transcript.fa -d AGPv3.25.transcript.collapsed.info \
    /Share/home/shibinbin/data/gtf/Zea_mays.AGPv3.25/annotation.chromosome.gff3
awk '/^>/{print;if(length(s) > 0) print s;s="";next} {s=s $0} END{if(length(s) > 0) print s}' \
    AGPv3.25.transcript.fa > AGPv3.25.transcript.nowrap.fa
mv AGPv3.25.transcript.nowrap.fa AGPv3.25.transcript.fa
awk 'FNR==NR{chr[$1]=$2;start[$1]=$4}
FNR!=NR{
if($0 ~/^>/){ match($0, /^>(\w+)/, name);
printf "%s (leftmost exon at %s:%s)\n",$0,chr[name[1]],start[name[1]];next
}else{
print
}}' /Share/home/shibinbin/data/gtf/Zea_mays.AGPv3.25/annotation.chromosome.gp AGPv3.25.transcript.fa > AGPv3.25.transcript.annovar.fa
samtools faidx AGPv3.25.transcript.fa
```

## The ANNOVAR software

### File `annotate_variation.pl`

* Function `readSeqFromFASTADB()`: Read FASTA file from `${dbloc}/${buildver}_${dbtype1}Mrna.fa`.
`$dbtype1` is either *refGene*, *ensGene* or *knownGene*.

* Function `readUCSCGeneAnnotation()`: Read gene annotations from `${dbloc}/${buildver}_${dbtype1}.txt`.
For *refGene* and *ensGene*, the 15 columns are: $name, $chr, $dbstrand, $txstart, $txend,
$cdsstart, $cdsend, $exoncount, $exonstart,
$exonend, $id, $name2, $cdsstartstat, $cdsendstat, $exonframes.

* Function `annotateExonicVariantsThread()`: Perform the exonic_variant_function annotation
 (that is, whether the varint is missense, nonsense, etc), based on `$refseqvar`
 produced by `processNextQueryBatchByGeneThread()`.

## Annotate the variants

### Convert the emaize genotype files to vcf files
```bash
[ -d annovar ] || mkdir annovar
for i in $(seq 1 1);do
    zcat /Share/home/shibinbin/data/emaize/genotype/chr${i}_emaize.genoMat.gz \
        | bin/genotype_to_avinput.py /Share/home/shibinbin/data/genomes/fasta/Zea_mays/AGPv3.25.fa \
        > annovar/chr${i}.avinput
done
```
### Prepare ANNOVAR database
```bash
[ -d annovardb ] || mkdir annovardb
ln -f -s /Share/home/shibinbin/data/genomes/fasta/Zea_mays/AGPv3.25.transcript.annovar.fa annovardb/Zea_mays_refGeneMrna.fa
ln -f -s /Share/home/shibinbin/data/gtf/Zea_mays.AGPv3.25/annotation.chromosome.gp annovardb/Zea_mays_refGene.txt
```
### Run ANNOVAR
```bash
export PATH=$PATH:/Share/home/shibinbin/pkgs/annovar/20170104
for i in $(seq 1 1);do
    annotate_variation.pl --build Zea_mays --geneanno -dbtype refGene --out annovar/chr${i} annovar/chr${i}.avinput annovardb/
done
```
