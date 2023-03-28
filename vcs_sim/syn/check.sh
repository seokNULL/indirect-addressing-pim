#!/bin/bash
FILE=PE_syn.log
CHAR1="error"
CHAR2="latch"
CHAR3="drive"
CHAR4="multiple"
echo " "
echo "VERILOG SYN ERR CHECK"
echo " "
echo "Current Path : "
pwd

echo "FIND :" $CHAR1 
echo "result"
echo " "
grep -niI $CHAR1 $FILE

echo "FIND : " $CHAR2 
echo "result"
echo " "
grep -niI $CHAR2 $FILE

echo "FIND : " $CHAR3 
echo "result"
echo " "
grep -niI $CHAR3 $FILE

echo "FIND : " $CHAR4 
echo "result"
echo " "
grep -niI $CHAR4 $FILE
