module BTN_SW_BFM
   (
    // Push-buttons
    output reg    BTN_0        ,
    output reg    BTN_1        ,
    output reg    BTN_2        ,
    output reg    BTN_3        ,

    // Slider switches
    output reg    SW_0         ,
    output reg    SW_1         ,
    output reg    SW_2         ,
    output reg    SW_3         ,
    output reg    SW_4         ,
    output reg    SW_5         ,
    output reg    SW_6         ,
    output reg    SW_7        
    );


   initial
      begin : RESET_ALL_OUTPUTS
	 BTN_0        = 1'b0;
	 BTN_1        = 1'b0;
	 BTN_2        = 1'b0;
	 BTN_3        = 1'b0;

	 SW_0         = 1'b0;
	 SW_1         = 1'b0;
	 SW_2         = 1'b0;
	 SW_3         = 1'b0;
	 SW_4         = 1'b0;
	 SW_5         = 1'b0;
	 SW_6         = 1'b0;
	 SW_7         = 1'b0;
      end
   

   task automatic BtnPush (input int ButtonNumber);
      begin
	 case (ButtonNumber)
	   0 : BTN_0        = 1'b1;
	   1 : BTN_1        = 1'b1;
	   2 : BTN_2        = 1'b1;
	   3 : BTN_3        = 1'b1;
	   default : $display("[ERROR] Button number %03d doesn't exist", ButtonNumber);
	 endcase // case (ButtonNumber)
      end
   endtask // endtask

   
   task automatic BtnRelease (input int ButtonNumber);
      begin
	 case (ButtonNumber)
	   0 : BTN_0        = 1'b0;
	   1 : BTN_1        = 1'b0;
	   2 : BTN_2        = 1'b0;
	   3 : BTN_3        = 1'b0;
	   default : $display("[ERROR] Button number %03d doesn't exist", ButtonNumber);
	 endcase // case (ButtonNumber)
      end
   endtask // endtask
   
   task automatic SwClose (input int ButtonNumber);
      begin
	 case (ButtonNumber)
	   0 : SW_0  = 1'b1;
	   1 : SW_1  = 1'b1;
	   2 : SW_2  = 1'b1;
	   3 : SW_3  = 1'b1;
	   4 : SW_4  = 1'b1;
	   5 : SW_5  = 1'b1;
	   6 : SW_6  = 1'b1;
	   7 : SW_7  = 1'b1;
	   default : $display("[ERROR] Switch number %03d doesn't exist", ButtonNumber);
	 endcase // case (ButtonNumber)
      end
   endtask // endtask

   
   task automatic SwOpen (input int ButtonNumber);
      begin
	 case (ButtonNumber)
	   0 : SW_0  = 1'b0;
	   1 : SW_1  = 1'b0;
	   2 : SW_2  = 1'b0;
	   3 : SW_3  = 1'b0;
	   4 : SW_4  = 1'b0;
	   5 : SW_5  = 1'b0;
	   6 : SW_6  = 1'b0;
	   7 : SW_7  = 1'b0;
	   default : $display("[ERROR] Switch number %03d doesn't exist", ButtonNumber);
	 endcase // case (ButtonNumber)
      end
   endtask // endtask
   
   task automatic readSwitches (output byte swStatus);
      begin

	 swStatus = {SW_0 ,
		     SW_1 ,
		     SW_2 ,
		     SW_3 ,
		     SW_4 ,
		     SW_5 ,
		     SW_6 ,
		     SW_7 };

      end
   endtask // endtask


  
endmodule
