#!/bin/bash
#
# Kwik script to annotate logo and blue bar
#
convert maplogo.bluebar.png -stroke none -fill white -gravity southwest -font /home/triton/.fonts/calibri.ttf -pointsize 24 -annotate +5+5 "Participant's Questionnaire" maplogo.bluebar.part.png

convert bluebar.qx.png  -font /home/triton/.fonts/calibri.ttf -pointsize 24 -stroke none -fill white -gravity west -annotate +5+0 "Participant's Questionnaire" -gravity east -fill "#45526e" -annotate +10+0 "Q1" bluebar.q1.png

convert maplogo.bluebar.png -stroke none -fill white -gravity southwest -font /home/triton/.fonts/calibri.ttf -pointsize 24 -annotate +5+5 "Key Personnel Questionnaire" maplogo.bluebar.peer.png

convert maplogo.bluebar.png -stroke none -fill white -gravity southwest -font /home/triton/.fonts/calibri.ttf -pointsize 24 -annotate +5+5 "Supervisor / Partner Questionnaire" maplogo.bluebar.boss.png




