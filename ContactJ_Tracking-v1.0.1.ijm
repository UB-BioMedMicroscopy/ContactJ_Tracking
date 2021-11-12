/*
Advanced Optical Microscopy Unit
Scientific and Technological Centers. Clinic Medicine Campus
UNIVERSITY OF BARCELONA
C/ Casanova 143
Barcelona 08036 
Tel: 34 934037159

------------------------------------------------
Gemma Martin (gemmamartin@ub.edu) , Maria Calvo (mariacalvo@ub.edu)
------------------------------------------------

Name of Macro: ContactJ_Track.ijm


Date: 02 November 2021

Objective: Analyse contacts between fluorescently labelled vesicles (late endosomes) and Endoplasmic Reticulum (ER) from cultured cells in confocal microscopy images. 
Input: Time lapse movie
Output: Image with contacts highlighted and a results .txt file
Requirements: Trackmate plugin

Version: ImageJ 1.53c

*/

// Init ImageJ parameters
IJ.deleteRows(0, nResults);
roiManager("reset");
run("Options...", "iterations=1 count=1");
roiManager("Associate", "true");
roiManager("Centered", "false");
roiManager("UseNames", "false");

if(nImages>0){

	// get folder to save results
	dir = getDirectory("Choose results folder");
	dirRes=dir+"Results"+File.separator;
	File.makeDirectory(dirRes);

	// get title of the original image
	title=getTitle();
	t=title;
	
	
	// Create .txt file where the results will be saved		
	path = dirRes+t+"_Results.txt";			
	File.append( "Frame \t Area vesicle (um2) \t X vesicle \t Y vesicle \t ID Track 1 \t ID Track 2 \t ID Track 3 \t ID Track 4 \t  Contact length (um)", path);
	
				
	//apply gaussian blur filter and duplicate the image to apply the analysis to the new one
	run("Gaussian Blur...", "sigma=0.75 stack");
	ImageID=getImageID();
	run("Duplicate...", "duplicate");
	
	//split channels and rename each channel. 
	run("Split Channels");
	
	for (j=1; j<=nImages; j++) {
	
		selectImage(j);
		title=getTitle();
		        	
		if (matches(title,".*C1.*")==1){   //Change the condition .*C1*. if the red channel is different
			run("Red");
			rename("Red");
			run("Subtract Background...", "rolling=30"); 	 		
			getPixelSize(unit, pixelWidth, pixelHeight);
		}		
	
		if (matches(title,".*C2.*")==1){  //Change the condition .*C2*. if the green channel is different	        	
			rename("Green");
			run("Green");
			run("Subtract Background...", "rolling=30");       
		}	
	}
	
	//merge channels red and green
	run("Merge Channels...", "c1=Red c2=Green");
	
	//apply registration to time lapse image
	run("StackReg", "transformation=[Rigid Body]");
	
	//split channels again
	run("Split Channels");
	
	// Get ID and rename of red and green channels after the registration
	selectWindow("RGB (green)");
	rename("Green");
	green=getImageID();
	run("Green");
	selectWindow("RGB (red)");
	red=getImageID();
	run("Red");
	rename("Red");
	selectWindow("RGB (blue)");
	close();
				
	
	// ******************************** Colocalization Vesicles ER ***************************************
	//********************************************************************************************************************
	
	//get values of threshold for green channel 
	selectImage(green);
	setAutoThreshold("Moments dark");
	waitForUser("Please, choose the correct threshold for green channel and then click OK");
	getThreshold(thresholdgreen,thresholdgreen2);
	
	//get values of threshold for red channel 	
	selectImage(red);
	run("Duplicate...", "duplicate");
	setAutoThreshold("Triangle dark");
	waitForUser("Please, choose the correct threshold for red channel and then click OK");
	getThreshold(thresholdred,thresholdred2);
				
	thresholdok=getString("Please, select the autothreshold for red channel", "Triangle");
	run("Convert to Mask", "method="+thresholdok+" background=Dark");
	rename("redmask");
				
	//colocalization using previous autothresholds
	run("Colocalization Highligter", "channel_1=[Red] channel_2=[Green] ratio=30 threshold_channel_1="+thresholdred+" threshold_channel_2="+thresholdgreen+" display=255 colocalized");
	//run("Split Channels");
	
	//using the colocalized image of colocalization highlighter and combining it with skeletonize, the colocalized perimeter is obtained. 
	selectWindow("Colocalized points (8-bit) ");
	run("Invert LUT");
	
	//************************************** Skeletonize **********************************************************
	
	//selection of Vesicles masks to obtain Segmented particles of Vesicles
	selectWindow("Red");
	
	//run("Analyze Particles...", "size=0-Infinity pixel show=Masks");		
	input = getImageID();
	n = nSlices();
	
	setBatchMode(true);
	for (i=1; i<=n; i++) {
	
		selectImage(input);
		setSlice(i);
		run("Find Maxima...", "prominence=5 output=[Segmented Particles]");
		if (i==1) {
			output = getImageID();
		} else  { 
			run("Select All");
			run("Copy");
			close();
			selectImage(output);
			run("Add Slice");
			run("Paste");
		}
	}
	setBatchMode(false);
	titlesegmented=getTitle();
	
	//Min image calculator between vesicles segmented particles and colocalization mask
	imageCalculator("Min create stack", "Colocalized points (8-bit) ",titlesegmented);
				
	//Skeletonization of the obtained mask
	run("Skeletonize", "stack");
	rename("contacts");
	run("Grays");
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	
	//Create new images with contacts
	run("Merge Channels...", "c1=Red c2=Green c3=[contacts] create keep");
	
	//**************************** red mask for trackmate ****************************************
	
	// Red mask segmented
	imageCalculator("Min create stack", "redmask",titlesegmented);
	
	//reset roiManager
	roiManager("reset");
	
	//median filter to mask
	run("Median 3D...", "x=1 y=1 z=1");
	run("Make Binary", "method=Yen background=Dark");
	
	//Analyze particles to obtain the Rois of vesicles
	run("Analyze Particles...", "size=10-Infinity pixel add show=Masks stack");
	vestotal=roiManager("count");
	
	roiManager("Show All");
	roiManager("Show None");
	
	//rename to vesmask (mask of vesicles)
	rename("vesmask");
	
	//Apply manually trackmate
	waitForUser("Please, apply trackmate with the correct parameters. Export label image with spots as single pixels. Then click OK");
	
	// ********************* measurements **********************************
	
	IJ.deleteRows(0, nResults);	
	
	//image tracks
	run("Set Measurements...", "area min centroid stack display redirect=None decimal=5");
	selectWindow("LblImg_vesmask");
	roiManager("Show All");
	roiManager("Show None");
	roiManager("Measure");
		
		
	//image contacts
	run("Set Measurements...", "area min centroid stack limit display redirect=None decimal=5");
	selectWindow("contacts");
	setThreshold(1, 255);
	roiManager("Show All");
	roiManager("Show None");
	
	roiManager("Measure");
	
	//Get all measurements values from Results window
	for (i = 0; i < vestotal; i++) {
					
		Areaves=getResult("Area", i);
		IDtrack=getResult("Max", i);
		slice=getResult("Slice", i);
		CenterX=getResult("X", i);
		CenterY=getResult("Y", i);
		Areacontact=getResult("Area", vestotal+i);
	
		selectWindow("LblImg_vesmask");
		roiManager("select", i);
	
		getHistogram(values, counts, 65536);
	
		tracks=0;
		numtrack=0;
		numtrack2=0;
		numtrack3=0;
		numtrack4=0;
					
		for (m = 1; m < 65536; m++) {
			if(counts[m]>0){
				tracks++;
				if(tracks==1){
					numtrack=m;
				}else if(tracks==2){
					numtrack2=m;
				}else if(tracks==3){
					numtrack3=m;
				} else {
					numtrack4=m;
				}
			}
		}
		
		// Write the results in .txt file				
		File.append( slice+"\t"+ Areaves+"\t"+CenterX+"\t"+CenterY+"\t"+numtrack+"\t"+numtrack2+"\t"+numtrack3+"\t"+numtrack4+"\t"+numtrack3+"\t"+Areacontact*pixelWidth, path);
	
	}
	
	//change visualization of the mask of vesicles 
	selectWindow("vesmask");
	run("16-bit");
	run("glasbey");
	
	//Create a vesicles image with the ID track as color
	setBatchMode(true);
	for (i = 0; i < vestotal; i++) {
		IDtrack=getResult("Max", i);
		roiManager("select", i);
		ratio=IDtrack/255;
		run("Multiply...", "value="+ratio+" slice");	
	}
	setBatchMode(false);
	
	
	//Create an image with vesicles and contacts 
	selectWindow("contacts");
	run("16-bit");
	run("Merge Channels...", "c1=vesmask c3=[contacts] create keep");
	
	//Macro has finised
	waitForUser("Macro has finished");

} else {
	
	waitForUser("Please, open a time lapse movie before running ContactJ_Track macro");
}
	
