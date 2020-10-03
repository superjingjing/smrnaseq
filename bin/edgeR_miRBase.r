#!/usr/bin/env Rscript

# Command line arguments
args = commandArgs(trailingOnly=TRUE)

input <- as.character(args[1:length(args)])

# Load / install required packages
if (!require("limma")){
    source("http://bioconductor.org/biocLite.R")
    biocLite("limma", suppressUpdates=TRUE)
    library("limma")
}

if (!require("edgeR")){
    source("http://bioconductor.org/biocLite.R")
    biocLite("edgeR", suppressUpdates=TRUE)
    library("edgeR")
}

if (!require("statmod")){
    install.packages("statmod", dependencies=TRUE, repos='http://cloud.r-project.org/')
    library("statmod")
}

if (!require("data.table")){
    install.packages("data.table", dependencies=TRUE, repos='http://cloud.r-project.org/')
    library("data.table")
}

if (!require("gplots")) {
    install.packages("gplots", dependencies=TRUE, repos='http://cloud.r-project.org/')
    library("gplots")
}

if (!require("methods")) {
    install.packages("methods", dependencies=TRUE, repos='http://cloud.r-project.org/')
    library("methods")
}

# Put mature and hairpin count files in separated file lists
filelist<-list()
filelist[[1]]<-input[grep(".mature.stats",input)]
filelist[[2]]<-input[grep(".hairpin.stats",input)]
names(filelist)<-c("mature","hairpin")
print(filelist)

for (i in 1:2) {
    header<-names(filelist)[i]

    # Prepare the combined data frame with gene ID as rownames and sample ID as colname
    data<-do.call("cbind", lapply(filelist[[i]], fread, header=FALSE, select=c(3)))
    unmapped<-do.call("cbind", lapply(filelist[[i]], fread, header=FALSE, select=c(4)))
    data<-as.data.frame(data)
    unmapped<-as.data.frame(unmapped)

    temp <- fread(filelist[[i]][1],header=FALSE, select=c(1))
    rownames(data)<-temp$V1
    rownames(unmapped)<-temp$V1
    colnames(data)<-gsub(".stats","",basename(filelist[[i]]))
    colnames(unmapped)<-gsub(".stats","",basename(filelist[[i]]))

    a=data[rownames(data)!="*",]
    a=as.matrix(a)
    rownames(a)=rownames(data)[rownames(data)!="*"]
    colnames(a)=colnames(data)
    data=a
    #data<-data[rownames(data)!="*",]
    #unmapped<-unmapped[rownames(unmapped)=="*",]
    b=unmapped[rownames(unmapped)!="*",]
    b=as.matrix(b)
    rownames(b)=rownames(unmapped)[rownames(unmapped)!="*"]
    colnames(b)=colnames(unmapped)
    unmapped=b

    # Write the summary table of unmapped reads
    write.table(unmapped,file=paste(header,"_unmapped_read_counts.txt",sep=""),sep='\t',quote=FALSE)

    # Remove genes with 0 reads in all samples
    #data<-data[!row_sub,]
    row_sub = apply(data, 1, function(row) all(row ==0 ))
    a<-data[!row_sub,]
    a=as.matrix(a)
    colnames(a)=colnames(data)
    data=a
        
                    
                    
    # Normalization
    dataDGE<-DGEList(counts=data,genes=rownames(data))
    o <- order(rowSums(dataDGE$counts), decreasing=TRUE)
    dataDGE <- dataDGE[o,]
    dataNorm <- calcNormFactors(dataDGE)

    # Print normalized read counts to file
    dataNorm_df<-as.data.frame(cpm(dataNorm))
    write.table(dataNorm_df,file=paste(header,"_normalized_CPM.txt",sep=""),sep='\t',quote=FALSE)

    # Print heatmap based on normalized read counts
    pdf(paste(header,"_CPM_heatmap.pdf",sep=""))
    heatmap.2(cpm(dataNorm),col=redgreen(100),key=TRUE,scale="row",density.info="none",trace="none")
    dev.off()

    # Make MDS plot (only perform with 3 or more samples)
    if (ncol(data)>2){
        pdf(paste(header,"_edgeR_MDS_plot.pdf",sep=""))
        MDSdata <- plotMDS(dataNorm)
        dev.off()

        # Print distance matrix to file
        write.table(MDSdata$distance.matrix, paste(header,"_edgeR_MDS_distance_matrix.txt",sep=""), quote=FALSE, sep="\t")

        # Print plot x,y co-ordinates to file
        MDSxy = MDSdata$cmdscale.out
        colnames(MDSxy) = c(paste(MDSdata$axislabel, '1'), paste(MDSdata$axislabel, '2'))

        write.table(MDSxy, paste(header,"_edgeR_MDS_plot_coordinates.txt",sep=""), quote=FALSE, sep="\t")

        # Get the log counts per million values
        logcpm <- cpm(dataNorm, prior.count=2, log=TRUE)

        # Calculate the euclidean distances between samples
        dists = dist(t(logcpm))

        # Plot a heatmap of correlations
        pdf(paste(header,"_log2CPM_sample_distances_heatmap.pdf",sep=""))
        hmap <- heatmap.2(as.matrix(dists),main="Sample Correlations", key.title="Distance", trace="none",dendrogram="row", margin=c(9, 9))
        dev.off()

        # Plot the heatmap dendrogram
        pdf(paste(header,"_log2CPM_sample_distances_dendrogram.pdf",sep=""))
        plot(hmap$rowDendrogram, main="Sample Dendrogram")
        dev.off()

        # Write clustered distance values to file
        write.table(hmap$carpet, paste(header,"_log2CPM_sample_distances.txt",sep=""), quote=FALSE, sep="\t")
    }
}

file.create("corr.done")

# Print sessioninfo to standard out
print("Sample correlation info:")
sessionInfo()
