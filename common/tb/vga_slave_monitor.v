// Copied from http://tinyvga.com/vga-timing/640x480@60Hz
// 
// VGA Signal 640 x 480 @ 60 Hz Industry standard timing
// 
// Interested in easy to use VGA solution for embedded applications? Click here!
// 
// General timing
// Screen refresh rate	60 Hz
// Vertical refresh	31.46875 kHz
// Pixel freq.	25.175 MHz
// Horizontal timing (line)
// Polarity of horizontal sync pulse is negative.
// 
// Scanline part	Pixels	Time [µs]
// Visible area	640	25.422045680238
// Front porch	16	0.63555114200596
// Sync pulse	96	3.8133068520357
// Back porch	48	1.9066534260179
// Whole line	800	31.777557100298
// Vertical timing (frame)
// Polarity of vertical sync pulse is negative.
// 
// Frame part	Lines	Time [ms]
// Visible area	480	15.253227408143
// Front porch	10	0.31777557100298
// Sync pulse	2	0.063555114200596
// Back porch	33	1.0486593843098
// Whole frame	525	16.683217477656
// 

module VGA_SLAVE_MONITOR
   #(parameter  STORE_IMAGES        =   1,
     parameter  COMPARE_IMAGES      =   1,
     parameter  string COMPARE_IMAGE_FILE = "frame_ref.ppm",
     parameter  PCLK_PERIOD_NS      =  40,
     
     parameter  HORIZ_SYNC          =  96, // 0 to 95
     parameter  HORIZ_BACK_PORCH    =  48, // 96 to 143
     parameter  HORIZ_ACTIVE_WIDTH  = 640, // 144 to 783
     parameter  HORIZ_FRONT_PORCH   =  16, // 784 to 799
     
     parameter  VERT_SYNC           =   2, // 0 to 1
     parameter  VERT_BACK_PORCH     =  33, // 2 to 34
     parameter  VERT_ACTIVE_HEIGHT  = 480, // 35 to 514
     parameter  VERT_FRONT_PORCH    =  10, // 515 to 524
     
     parameter R_HI = 23,
     parameter R_LO = 16,
     parameter G_HI = 15,
     parameter G_LO =  8,
     parameter B_HI =  7,
     parameter B_LO =  0,
     
     parameter  COLOUR_DEPTH        =   8
     )
   (
    input        	     PCLK     ,
    input       	     VSYNC_IN ,
    input       	     HSYNC_IN ,   
    input [COLOUR_DEPTH-1:0] RED_IN   ,
    input [COLOUR_DEPTH-1:0] GREEN_IN ,
    input [COLOUR_DEPTH-1:0] BLUE_IN

    
    );

   // Derived parameters
   parameter  HORIZ_WIDTH = HORIZ_FRONT_PORCH + HORIZ_ACTIVE_WIDTH + HORIZ_BACK_PORCH ;
   parameter  VERT_HEIGHT = VERT_FRONT_PORCH  + VERT_ACTIVE_HEIGHT + VERT_BACK_PORCH  ;

   parameter  PCLK_HALF_PERIOD_NS = PCLK_PERIOD_NS /2;

   int 		frameCnt = 0;
   int 		xCnt;
   int 		yCnt;

//   int 		vsyncFallingEdge   ;
   int 		vsyncRisingEdge    ;
//   int 		hsyncFallingEdge   ;
   int 		hsyncRisingEdge    ;


   reg  vsyncReg;
   reg  hsyncReg;

   wire vsyncFedge;
   wire hsyncFedge;
   wire vsyncRedge;
   wire hsyncRedge;
   
   wire ActiveArea = (  ((yCnt >= VERT_SYNC   + VERT_BACK_PORCH) && (yCnt <= VERT_SYNC  + VERT_BACK_PORCH  + VERT_ACTIVE_HEIGHT - 1))
		     && ((xCnt >= HORIZ_SYNC + HORIZ_BACK_PORCH) && (xCnt <= HORIZ_SYNC + HORIZ_BACK_PORCH + HORIZ_ACTIVE_WIDTH - 1))
			);

   assign vsyncFedge =  vsyncReg & ~VSYNC_IN;
   assign hsyncFedge =  hsyncReg & ~HSYNC_IN;
   assign vsyncRedge = ~vsyncReg &  VSYNC_IN;
   assign hsyncRedge = ~hsyncReg &  HSYNC_IN;

   always @(negedge PCLK)
   begin
      vsyncReg <= VSYNC_IN;
      hsyncReg <= HSYNC_IN;
   end
   
   always @(negedge PCLK)
   begin

      // If both have falling edges it's the start of a frame
      if (vsyncFedge && hsyncFedge)
      begin
	 $display("[INFO ] New Frame #%2d at time %t", frameCnt, $time);
	 xCnt = 0;
	 yCnt = 0;
	 frameCnt++;
      end

      // If only HSYNC falls it's the start of a new line, but not new frame
      else if (hsyncFedge)
      begin
	 xCnt = 0;
	 yCnt++;
 	 $display("[INFO ] New Line %3d at time %t", yCnt, $time);
      end

      else
      begin
	 xCnt++;
      end 
      

//      // Update the rising edge of hsync
//      else if (hsyncRedge)
//      begin	 
//	 hsyncRisingEdge = xCnt - 1;
//      end
//
//      // Update the rising edge of vsync
//      else if (vsyncRedge)
//      begin
//	 vsyncRisingEdge = yCnt - 1;
//      end
//
      
   end
   
     

   generate if (STORE_IMAGES)
   begin : PIXEL_STORAGE

      int outFile;

      string outFileName;
      
      // New approach to storing the image. Open the file on the negedge of VSYNC, close the file if open 
      // close the file if it's open
      always @(negedge VSYNC_IN)
      begin : close_file
	 if (outFile) 
	    begin
	       $display("[INFO ] Closing output file at time %t", $realtime);
	       $fclose(outFile);
	    end
      end

      // open a new file - todo ! Add the frame number
      always @(posedge VSYNC_IN)
      begin : open_file
	 $display("[INFO ] Opening output file at time %t", $realtime);
	 
	 $sformat(outFileName, "%1d", frameCnt);
	 outFileName = {"frame_", outFileName, ".ppm"};
	 
	 outFile = $fopen(outFileName, "w");
 	 $fdisplay(outFile, "P3"); // Code for ASCII ppm file
 	 $fdisplay(outFile, "# Frame number %03d", frameCnt); // Code for ASCII ppm file
 	 $fdisplay(outFile, "%03d  %03d", HORIZ_ACTIVE_WIDTH, VERT_ACTIVE_HEIGHT); // Width Height of the image
 	 $fdisplay(outFile, "%03d", (2 ** COLOUR_DEPTH)-1); // Max colour of the image
      end

      // Update the counters on the negedge, store pixel on the posedge so it is lined up correctly
      always @(posedge PCLK)
      begin : write_pixel
	 if (ActiveArea) 
	 begin
	    $fdisplay(outFile, "%3d, %3d, %3d", RED_IN, GREEN_IN, BLUE_IN);
//	    $display("[INFO ] Pixel X = %3d, Y = %3d, R = %3d, G = %3d, B = %3d", xCnt, yCnt, RED_IN, GREEN_IN, BLUE_IN);
	 end
	 
      end

   end
      
   endgenerate
   
   // Extra always block to compare the image line-by-line with a reference frame
   generate if (COMPARE_IMAGES)
   begin : IMAGE_COMPARE

      int inFile;

      string inFileName = COMPARE_IMAGE_FILE;

      string line;

      int    lineNum;

      byte   fileRed;
      byte   fileGreen;
      byte   fileBlue;

      int    testPass = 1;
      int    returnVal;
      
      // open a new file - todo ! Add the frame number
      always @(posedge VSYNC_IN)
      begin : open_file
	 $display("[INFO ] Opening comparison file %s at time %t", inFileName, $time);
	 
	 inFile = $fopen(inFileName, "r");
         lineNum = 0;
         
         repeat (4)
         begin : HDR_READ
            lineNum++;
            returnVal = $fgets(line, inFile);
            $display("[DEBUG] Dropping line %1d : %s at time %t", lineNum, line, $time);
           end

         // Wait until the active area
         forever
            begin : PIXEL_READ_COMPARE
               
               while (!(ActiveArea || !VSYNC_IN))
                  @(posedge PCLK);

               if (!VSYNC_IN) break;
               
               returnVal = $fscanf(inFile, "%d, %d, %d", fileRed, fileGreen, fileBlue);

               if (   (fileRed   == RED_IN   ) 
                   && (fileGreen == GREEN_IN )
                   && (fileBlue  == BLUE_IN  )
                      )
               begin
//                  $display("[DEBUG] Pixel Match at time %t", $time);
               end
               else
               begin
                  $display("[ERROR] Pixel Mismatch at time %t", $time);
                  $display("[ERROR] Read in RED = 0x%x, GREEN = 0x%x, BLUE = %x at time %t", fileRed, fileGreen, fileBlue, $time);
                  $display("[ERROR] Actual  RED = 0x%x, GREEN = 0x%x, BLUE = %x at time %t", RED_IN , GREEN_IN , BLUE_IN , $time);
                  testPass = 0;
               end

               @(posedge PCLK);

            end

         if (testPass)
         begin
            $display("[PASS ] Test PASSED !");
         end
         else
         begin
            $display("[FAIL ] Test FAILED !");
         end
      end
   end
      
   endgenerate
   
     
      

endmodule
