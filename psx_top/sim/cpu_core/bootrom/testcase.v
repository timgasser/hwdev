// `define ROM_BFM     TB_PSX_TOP.wb_slave_bfm_rom
// `define SDRAM_BFM   TB_PSX_TOP.wb_slave_bfm_sdram
// `define GPU_RAM_BFM TB_PSX_TOP.wb_slave_bfm_gpu_local_ram

module TESTCASE ();

`include "tb_defines.v"
   
   parameter string BOOTROM_FILE = "SCPH1001.BIN";
   
// Load the bootrom into the ROM BFM   
initial
   begin
      
      int romFileId;

      $display("[INFO ] Loading %s", BOOTROM_FILE);
      romFileId = $fopen(BOOTROM_FILE, "rb");

      assert ($fread(`ROM.MemArray, romFileId));
 
      $fclose(BOOTROM_FILE);
      
   end

   initial
      begin
//         #100ms;
//         $display("[INFO ] Stopping sim at 100ms");
//         $finish();
      end
   


endmodule
