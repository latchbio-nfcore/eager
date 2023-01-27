//
// Prepare reference indexing for downstream
//

include { FASTQ_ALIGN_BWAALN                             } from '../../subworkflows/nf-core/fastq_align_bwaaln/main'
include { SAMTOOLS_FLAGSTAT as SAMTOOLS_FLAGSTAT_MAPPED  } from '../../modules/nf-core/samtools/flagstat/main'

workflow MAP {
    take:
    reads // [ [meta], [read1, reads2] ] or [ [meta], [read1] ]
    index // [ [meta], [ index ] ]

    main:
    ch_versions       = Channel.empty()
    ch_multiqc_files  = Channel.empty()

    ch_input_for_mapping = reads
                            .combine(index)
                            .multiMap {
                                meta, reads, meta2, index ->
                                    reads: [ meta, reads ]
                                    index: [ meta2, index]
                            }

    if ( params.mapping_tool == 'bwaaln' ) {
        FASTQ_ALIGN_BWAALN ( ch_input_for_mapping.reads, ch_input_for_mapping.index )

        ch_versions   = ch_versions.mix ( FASTQ_ALIGN_BWAALN.out.versions )
        ch_mapped_bam = FASTQ_ALIGN_BWAALN.out.bam
        ch_mapped_bai = params.fasta_largeref ? FASTQ_ALIGN_BWAALN.out.csi : FASTQ_ALIGN_BWAALN.out.bai

    }

    ch_input_for_flagstat = ch_mapped_bam.join( ch_mapped_bai, failOnMismatch: true )

    SAMTOOLS_FLAGSTAT_MAPPED ( ch_input_for_flagstat)
    ch_versions.mix( SAMTOOLS_FLAGSTAT.out.versions )
    ch_multiqc_files = ch_multiqc_files.mix( SAMTOOLS_FLAGSTAT.out.flagstat )

    emit:
    bam        = ch_mapped_bam                      // [ [ meta ], bam ]
    bai        = ch_mapped_bai                      // [ [ meta ], bai ]
    flagstat   = SAMTOOLS_FLAGSTAT.out.flagstat     // [ [ meta ], stats ]
    mqc        = ch_multiqc_files
    versions   = ch_versions

}
