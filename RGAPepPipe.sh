#!/bin/bash

#####
# Runs the RGA pipeline
# Usage: RGAPepPipe.sh <run_accession> <path/to/reference>
#####
# fastqc
/opt/PepPrograms/FastQC-0.11.8/fastqc $1_1.fastq.gz $1_2.fastq.gz -t 4

# trimGalore
/opt/PepPrograms/TrimGalore-0.6.4/trim_galore -q 15 --fastqc_args '-t 4' --paired $1_1.fastq.gz $1_2.fastq.gz
rm $1_?.fastq.gz

# bwaMEM
/opt/PepPrograms/bwa-0.7.12/bwa mem -M -t 8 $2 $1_1_val_1.fq.gz $1_2_val_2.fq.gz > $1.sam

# samtools
/opt/PepPrograms/samtools-1.3.1/samtools view -bhSu $1.sam > $1.bam
/opt/PepPrograms/samtools-1.3.1/samtools sort -O bam -T $1.tmp -o $1.sort.bam $1.bam
rm $1.sam
rm $1.bam

# picard
java -Xmx2g -jar /opt/PepPrograms/picard-tools-1.138/picard.jar MarkDuplicates I=$1.sort.bam O=$1.dedup.bam M=$1.metrics REMOVE_DUPLICATES=true AS=true VALIDATION_STRINGENCY=SILENT
java -Xmx2g -jar /opt/PepPrograms/RGAPipeline/picard.jar AddOrReplaceReadGroups I=$1.dedup.bam O=$1.ready.bam RGID=$1 RGLB=$1 RGPL=illumina RGPU=dummy-barcode RGSM=$1 VALIDATION_STRINGENCY=SILENT SORT_ORDER=coordinate CREATE_INDEX=true

# gatk
java -Xmx2g -jar /opt/PepPrograms/GenomeAnalysisTK.jar -I $1.ready.bam -R $2 -T RealignerTargetCreator -o $1.intervals
java -Xmx2g -jar /opt/PepPrograms/GenomeAnalysisTK.jar -I $1.ready.bam -R $2 -T IndelRealigner -targetIntervals $1.intervals -o $1.realn.bam

# vcf_pilon
java -jar /opt/PepPrograms/pilon-1.16.jar --genome $2 --frags $1.realn.bam --output $1_pilon --variant --mindepth 10 --minmq 40 --minqual 20

# bamqc
/opt/PepPrograms/qualimap_v2.2.1/qualimap bamqc -bam $1.realn.bam -outdir $1_bamqc
tar -zcvf $1.bamqc.tar.gz $1_bamqc/

# pilon_fasta
python pilonVCFtoFasta.py $1_pilon.vcf
