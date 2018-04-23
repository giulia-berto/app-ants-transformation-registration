#!/bin/bash

#------------------------------------------------------------------------------
# TRANSFORMATION USING T1 AND FA
#------------------------------------------------------------------------------


SUB_MOVE=$1
SUB_STAT=$2


#------------------------------------------------------------------------------
# Renaming files
#------------------------------------------------------------------------------

echo "renaming files"
T1W_MOVE=`jq -r '.t1_moving' config.json`
FA_MOVE=`jq -r '.fa_moving' config.json`
T1W_STAT=`jq -r '.t1_static' config.json`
FA_STAT=`jq -r '.fa_static' config.json`
cp $T1W_MOVE ./sub-${SUB_MOVE}_space-dwi_T1w.nii.gz;
cp $FA_MOVE ./sub-${SUB_MOVE}_var-FNA_FA.nii.gz
cp $T1W_STAT ./sub-${SUB_STAT}_space-dwi_T1w.nii.gz
cp $FA_STAT ./sub-${SUB_STAT}_var-FNA_FA.nii.gz

T1W_ANT_PRE=sub-${SUB_MOVE}_space_${SUB_STAT}_var-t1w_
FA_ANT_PRE=sub-${SUB_MOVE}_space_${SUB_STAT}_var-fa_


#------------------------------------------------------------------------------
# ANTS Registration of structural images
#------------------------------------------------------------------------------

# Warp Computation
ANTS 3 -m CC[${T1W_STAT},${T1W_MOVE},1,5] -t SyN[0.5] \
    -r Gauss[2,0] -o $T1W_ANT_PRE -i 30x90x20 --use-Histogram-Matching
ANTS 3 -m CC[${FA_STAT},${FA_MOVE},1,5] -t SyN[0.5] \
    -r Gauss[2,0] -o $FA_ANT_PRE -i 30x90x20 --use-Histogram-Matching


#------------------------------------------------------------------------------
# ANTS Registration of structural images
#------------------------------------------------------------------------------

mv ${T1W_ANT_PRE}Warp.nii.gz ${T1W_ANT_PRE}warp.nii.gz
mv ${T1W_ANT_PRE}InverseWarp.nii.gz ${T1W_ANT_PRE}invwarp.nii.gz
mv ${T1W_ANT_PRE}Affine.txt ${T1W_ANT_PRE}affine.txt

mv ${FA_ANT_PRE}Warp.nii.gz ${FA_ANT_PRE}warp.nii.gz
mv ${FA_ANT_PRE}InverseWarp.nii.gz ${FA_ANT_PRE}invwarp.nii.gz
mv ${FA_ANT_PRE}Affine.txt ${FA_ANT_PRE}affine.txt



#------------------------------------------------------------------------------
# REGISTRATION OF TRACTS
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# Setting filenames
#------------------------------------------------------------------------------

WARP_PRE=sub-${SUB_MOVE}_space_${SUB_STAT}_var-ant_warp
WARP_INI=sub-${SUB_MOVE}_space_${SUB_STAT}_var-ant_warp-i[].nii.gz
WARP_TMP=sub-${SUB_MOVE}_space_${SUB_STAT}_var-ant_warp-t[].nii.gz
WARP_FA=sub-${SUB_MOVE}_space_${SUB_STAT}_var-fa4tck_warp.nii.gz
WARP_T1W=sub-${SUB_MOVE}_space_${SUB_STAT}_var-t1w4tck_warp.nii.gz

ANT_PRE=$SRC/voxel_based_transformation/sub-${SUB_MOVE}
T1W_AFF=${T1W_ANT_PRE}affine.txt
T1W_IWARP=${T1W_ANT_PRE}invwarp.nii.gz
T1W_IWARP_FIX=${T1W_ANT_PRE}InverseWarp.nii.gz

FA_AFF=${FA_ANT_PRE}affine.txt
FA_IWARP=${FA_ANT_PRE}invwarp.nii.gz
FA_IWARP_FIX=${FA_ANT_PRE}InverseWarp.nii.gz

TCK_MOVE_PRE=sub-${SUB_MOVE}_var-AFQ_set-
TCK_OUT_PRE=sub-${SUB_MOVE}_space_${SUB_STAT}_

#------------------------------------------------------------------------------
# ANTS Registration of tractograms
#------------------------------------------------------------------------------

# Convert the warp for T1W
warpinit ${T1W_STAT} ${WARP_INI} -force -quiet
cp $T1W_IWARP $T1W_IWARP_FIX
for i in 0 1 2; do
    WarpImageMultiTransform 3 \
        ${WARP_PRE}-i${i}.nii.gz ${WARP_PRE}-t${i}.nii.gz \
        -R $T1W_STAT -i $T1W_AFF $T1W_IWARP_FIX
done
rm -f $T1W_IWARP_FIX
warpcorrect $WARP_TMP $WARP_T1W -force -quiet

# Convert the warp for FA
warpinit ${FA_STAT} ${WARP_INI} -force -quiet
cp $FA_IWARP $FA_IWARP_FIX
for i in 0 1 2; do
    WarpImageMultiTransform 3 \
        ${WARP_PRE}-i${i}.nii.gz ${WARP_PRE}-t${i}.nii.gz \
        -R $FA_STAT -i $FA_AFF $FA_IWARP_FIX
done
rm -f $FA_IWARP_FIX
warpcorrect $WARP_TMP $WARP_FA -force -quiet
rm ${WARP_PRE}-*

# Apply the warp
while read tract_name; do         
    echo "Tract name: $tract_name"; 
    tract=$tract_name'_tract.trk' 
    python trk2tck.py ${tract}
    tcknormalise $tract_name'_tract.tck' \
	$WARP_T1W ${TCK_OUT_PRE}var-ant4t1w_set-${tract_name}_tract.tck -force -quiet
    tcknormalise $tract_name'_tract.tck' \
	$WARP_FA ${TCK_OUT_PRE}var-ant4fa_set-${tract_name}_tract.tck -force -quiet
    python tck2trk.py ${T1W_MOVE} ${TCK_OUT_PRE}var-ant4t1w_set-${tract_name}_tract.tck
    python tck2trk.py ${T1W_MOVE} ${TCK_OUT_PRE}var-ant4fa_set-${tract_name}_tract.tck
done < tract_name_list.txt

