                    
// ROMs Using Block RAM Resources
// Verilog code for a ROM with registered output (template 1)
//
// This file is auto-generated ! Please do not edit!
// 
// The bootrom is up to 32kByte big, but will only contain valid data from code.hex
// It can use anything up to 16 BRAMs and there are only 48 in the FPGA (!).
// The max is therefore 8192 x 32 bit words. 
// So you need a 13 bit address, although some of these bits may be optimised away
// depending on how many values there are in the case statement below.

module INST_ROM (clk, en, addr, data);
    input      clk;
    input      en;
    input      [12:0] addr;
    output reg [31:0] data;
    always @(posedge clk) begin
        if (en)
            case(addr)
                  13'd0000: data <= 32'h24577449;
                  13'd0001: data <= 32'hE8F9FC82;
                  13'd0002: data <= 32'h2C6AAFCB;
                  13'd0003: data <= 32'hE3ABB484;
                  13'd0004: data <= 32'h2BBCB06C;
                  13'd0005: data <= 32'h7DE21C56;
                  13'd0006: data <= 32'h4DE0AEAE;
                  13'd0007: data <= 32'h45B1FE52;
                  13'd0008: data <= 32'h6DCAD2E8;
                  13'd0009: data <= 32'h0DA8A191;
                  13'd0010: data <= 32'h8102D09E;
                  13'd0011: data <= 32'hF0E086CA;
                  13'd0012: data <= 32'hCAD8B44E;
                  13'd0013: data <= 32'h9A4791F9;
                  13'd0014: data <= 32'hEEC1E009;
                  13'd0015: data <= 32'h013698CC;
                  13'd0016: data <= 32'hDAD117D0;
                  13'd0017: data <= 32'h08B1B186;
                  13'd0018: data <= 32'h3C8B2771;
                  13'd0019: data <= 32'hF1BC4D38;
                  13'd0020: data <= 32'h06F17DAF;
                  13'd0021: data <= 32'h8F84626A;
                  13'd0022: data <= 32'hBDD96FB0;
                  13'd0023: data <= 32'h119DF2B9;
                  13'd0024: data <= 32'h13EC6A5F;
                  13'd0025: data <= 32'hBB480035;
                  13'd0026: data <= 32'h683FF06B;
                  13'd0027: data <= 32'hB41033CC;
                  13'd0028: data <= 32'h3FBD13CC;
                  13'd0029: data <= 32'h1B6DDDA4;
                  13'd0030: data <= 32'h4F321BBE;
                  13'd0031: data <= 32'h4FBC2238;
                  13'd0032: data <= 32'hDD417474;
                  13'd0033: data <= 32'hAB441733;
                  13'd0034: data <= 32'h50DFB220;
                  13'd0035: data <= 32'h009F54B3;
                  13'd0036: data <= 32'h89C397DC;
                  13'd0037: data <= 32'h98EABD6B;
                  13'd0038: data <= 32'hFE875742;
                  13'd0039: data <= 32'h42DBDB99;
                  13'd0040: data <= 32'hB8D8EEEE;
                  13'd0041: data <= 32'h22C9B2CC;
                  13'd0042: data <= 32'hDBD9B2C4;
                  13'd0043: data <= 32'hB1934520;
                  13'd0044: data <= 32'hEFD0CFBF;
                  13'd0045: data <= 32'h99FAB8C9;
                  13'd0046: data <= 32'hEB10DA80;
                  13'd0047: data <= 32'h8E506BA1;
                  13'd0048: data <= 32'h57E04905;
                  13'd0049: data <= 32'h68E8F0E0;
                  13'd0050: data <= 32'h72F539D3;
                  13'd0051: data <= 32'h75C6BC38;
                  13'd0052: data <= 32'h5A04437D;
                  13'd0053: data <= 32'hA82AFFB4;
                  13'd0054: data <= 32'h0939BBAB;
                  13'd0055: data <= 32'hA1FF414C;
                  13'd0056: data <= 32'hB85E07A1;
                  13'd0057: data <= 32'h457B869A;
                  13'd0058: data <= 32'h9D30D818;
                  13'd0059: data <= 32'h800ADDF0;
                  13'd0060: data <= 32'h5BC3A798;
                  13'd0061: data <= 32'hC8F63408;
                  13'd0062: data <= 32'h74681014;
                  13'd0063: data <= 32'h9A22C00B;
                  13'd0064: data <= 32'hD09FC02C;
                  13'd0065: data <= 32'hD685174B;
                  13'd0066: data <= 32'hC2124BCF;
                  13'd0067: data <= 32'hD15939A2;
                  13'd0068: data <= 32'hDDA4A229;
                  13'd0069: data <= 32'h7F1466AF;
                  13'd0070: data <= 32'hD88C0F77;
                  13'd0071: data <= 32'h9EDEFC18;
                  13'd0072: data <= 32'hAD9C1DEC;
                  13'd0073: data <= 32'h87A020F9;
                  13'd0074: data <= 32'h70942C69;
                  13'd0075: data <= 32'h6E29D7A3;
                  13'd0076: data <= 32'hE1AD5C95;
                  13'd0077: data <= 32'h9FF89CF6;
                  13'd0078: data <= 32'h8E6F53F5;
                  13'd0079: data <= 32'h0A3698D6;
                  13'd0080: data <= 32'h1A5618D3;
                  13'd0081: data <= 32'h71C7D6DF;
                  13'd0082: data <= 32'h1B540F8E;
                  13'd0083: data <= 32'hDE02560E;
                  13'd0084: data <= 32'h3E6BADD1;
                  13'd0085: data <= 32'h57A0177D;
                  13'd0086: data <= 32'h3776EAC6;
                  13'd0087: data <= 32'hADF6D8E6;
                  13'd0088: data <= 32'h69319F7F;
                  13'd0089: data <= 32'hCB0E6CE5;
                  13'd0090: data <= 32'hF711F52B;
                  13'd0091: data <= 32'h342B71B4;
                  13'd0092: data <= 32'h8426D535;
                  13'd0093: data <= 32'h172EAAB3;
                  13'd0094: data <= 32'h99DA5D3C;
                  13'd0095: data <= 32'h41A9D92D;
                  13'd0096: data <= 32'h0E05A901;
                  13'd0097: data <= 32'h9E2D596C;
                  13'd0098: data <= 32'h0EFF3A22;
                  13'd0099: data <= 32'h3A934910;
                  13'd0100: data <= 32'h517FB4F5;
                  13'd0101: data <= 32'h24155EA0;
                  13'd0102: data <= 32'hBB8B5A70;
                  13'd0103: data <= 32'hF165B9C9;
                  13'd0104: data <= 32'h02A995B3;
                  13'd0105: data <= 32'hF0DBA5B6;
                  13'd0106: data <= 32'h5AD8CBE8;
                  13'd0107: data <= 32'h479E9F3C;
                  13'd0108: data <= 32'hFEAC8628;
                  13'd0109: data <= 32'h385327B5;
                  13'd0110: data <= 32'hDD184137;
                  13'd0111: data <= 32'h86D86B18;
                  13'd0112: data <= 32'hA814A57B;
                  13'd0113: data <= 32'h30592522;
                  13'd0114: data <= 32'h191ED732;
                  13'd0115: data <= 32'h94E2C81E;
                  13'd0116: data <= 32'h9CE1F55E;
                  13'd0117: data <= 32'h5ED421D2;
                  13'd0118: data <= 32'h7007F9FE;
                  13'd0119: data <= 32'h78348198;
                  13'd0120: data <= 32'h621306EC;
                  13'd0121: data <= 32'h6BD44497;
                  13'd0122: data <= 32'h925518EB;
                  13'd0123: data <= 32'h54D90F89;
                  13'd0124: data <= 32'h28601FAF;
                  13'd0125: data <= 32'hF67FF63E;
                  13'd0126: data <= 32'hDD426333;
                  13'd0127: data <= 32'h93CABC57;
                  default : data <= 32'h00000000;

            endcase
    end
endmodule
