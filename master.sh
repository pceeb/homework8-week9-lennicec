#!/bin/bash

In=""
Out=""
Met=""
Demux=""
Vis=""
Dada=""	
Tab=""
Stat=""
Aligned=""
Unrooted=""
Rooted=""
Core=""	
	
while getopts "i:o:m:x:v:a:t:s:n:u:r:c:" opt; do
	case $opt in
		i) In="$OPTARG"
		;;
		o) Out="$OPTARG"
		;;
		m) Met="$OPTARG"
        ;;
        x) Demux="$OPTARG"
        ;;
        v) Vis="$OPTARG"
        ;;
        a) Dada="$OPTARG"
		;;
		t) Tab="$OPTARG"
		;;
		s) Stat="$OPTARG"
		;;
		n) Aligned="$OPTARG"
		;;
		u) Unrooted="$OPTARG"
		;;
		r) Rooted="$OPTARG"
		;;
		c) Core="$OPTARG"
	esac
done
source /u/local/Modules/default/init/bash
module load python/anaconda2
source activate qiime2-2019.1

echo "Making directory called output-emp-single-end-sequences"

mkdir output-emp-single-end-sequences

echo "Using sequences.fastq.gz and barcodes.fastq.gz to make emp-single-end-sequences.qza to put in output-emp-single-end-sequences directory"

qiime tools import \
  --type EMPSingleEndSequences \
  --input-path ${In} \
  --output-path ${Out}/emp-single-end-sequences.qza
  
echo "Making directory called demultiplex-sequences"

mkdir demultiplex-sequences

echo "Generating demux.qza file where samples are assigned their proper sequence (goes in demultiplex-sequences directory"

qiime demux emp-single \
  --i-seqs ${Out}/emp-single-end-sequences.qza \
  --m-barcodes-file ${Met} \
  --m-barcodes-column BarcodeSequence \
  --o-per-sample-sequences ${Demux}/demux.qza
  
echo "Making directory called visuals"
  
mkdir visuals

echo "Generating a visual friendly version called demultiplex-sequences"

qiime demux summarize \
  --i-data ${Demux}/demux.qza \
  --o-visualization ${Vis}/demux.qzv

echo "Making directories called dada2, table-dada2, stats-dada2"

mkdir dada2
mkdir table-dada2
mkdir stats-dada2

echo "Removing low quality regions of the sequence on both ends. Files rep-seqs-dada2.qza, table-dada3.qza, and stats-dada2.qza will be saved in their respective directories"
echo "Also making visual friendly files (.qzv) of stats-dada2.qza"

qiime dada2 denoise-single \
  --i-demultiplexed-seqs ${Demux}/demux.qza \
  --p-trim-left 0 \
  --p-trunc-len 120 \
  --o-representative-sequences ${Dada}/rep-seqs-dada2.qza \
  --o-table ${Tab}/table-dada2.qza \
  --o-denoising-stats ${Stat}/stats-dada2.qza
qiime metadata tabulate \
  --m-input-file ${Stat}/stats-dada2.qza \
  --o-visualization ${Vis}/stats-dada2.qzv
  
echo "Redirecting into dada2 directory and renaming rep-seqs-dada2.qza to rep-seqs.qza"
echo "Redirecting into table-dada2 directory and renaming table-dada2.qza to table.qza"

cd dada2
mv rep-seqs-dada2.qza rep-seqs.qza
cd ../
cd table-dada2/
mv table-dada2.qza table.qza
cd ../

echo "Redirect into main directory and creating feature tables/ visual summaries of data thus far"

qiime feature-table summarize \
  --i-table ${Tab}/table.qza \
  --o-visualization ${Vis}/table.qzv \
  --m-sample-metadata-file ${Met}
qiime feature-table tabulate-seqs \
  --i-data ${Dada}/rep-seqs.qza \
  --o-visualization ${Vis}/rep-seqs.qzv

echo "Making directories called aligned-sequences, unrooted-tree, rooted-tree"

mkdir aligned-sequences
mkdir unrooted-tree
mkdir rooted-tree

echo "Generating aligned sequences without highly variable positions in effort to make a phylogenetic tree"
echo "Files masked-aligned-rep-seqs.qza, unrooted-tree.qza, and rooted-tree.qza will be saved in their respective directories" 

qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences ${Dada}/rep-seqs.qza \
  --o-alignment ${Aligned}/aligned-rep-seqs.qza \
  --o-masked-alignment ${Aligned}/masked-aligned-rep-seqs.qza \
  --o-tree ${Unrooted}/unrooted-tree.qza \
  --o-rooted-tree ${Rooted}/rooted-tree.qza

echo "Setting sampling depth parameter to ensure that sample depth is even across the samples" 

qiime diversity core-metrics-phylogenetic \
  --i-phylogeny ${Rooted}/rooted-tree.qza \
  --i-table ${Tab}/table.qza \
  --p-sampling-depth 1103 \
  --m-metadata-file ${Met} \
  --output-dir ${Core}
  
echo "Analyzing alpha diversity and creating visuals" 

qiime diversity alpha-group-significance \
  --i-alpha-diversity ${Core}/faith_pd_vector.qza \
  --m-metadata-file ${Met} \
  --o-visualization ${Vis}/faith-pd-group-significance.qzv

qiime diversity alpha-group-significance \
  --i-alpha-diversity ${Core}/evenness_vector.qza \
  --m-metadata-file ${Met} \
  --o-visualization ${Vis}\evenness-group-significance.qzv
  
echo "Analyzing beta diversity and creating visuals" 

qiime diversity beta-group-significance \
  --i-distance-matrix ${Core}/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file ${Met} \
  --m-metadata-column BodySite \
  --o-visualization ${Vis}/unweighted-unifrac-body-site-significance.qzv \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix ${Core}/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file ${Met} \
  --m-metadata-column Subject \
  --o-visualization ${Vis}/unweighted-unifrac-subject-group-significance.qzv \
  --p-pairwise

echo "Generting emperor plot and creating visuals" 

qiime emperor plot \
  --i-pcoa ${Core}/unweighted_unifrac_pcoa_results.qza \
  --m-metadata-file ${Met} \
  --p-custom-axes DaysSinceExperimentStart \
  --o-visualization ${Vis}/unweighted-unifrac-emperor-DaysSinceExperimentStart.qzv

qiime emperor plot \
  --i-pcoa core-metrics-results/bray_curtis_pcoa_results.qza \
  --m-metadata-file sample-metadata.tsv \
  --p-custom-axes DaysSinceExperimentStart \
  --o-visualization ${Vis}/bray-curtis-emperor-DaysSinceExperimentStart.qzv

echo "Success! Now you have finished the tutorial and have generated visuals (.qzv files) that you can drag onto QIIME2 View website to view!"

