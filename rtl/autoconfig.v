/*
 * Copyright (C) 2023 Matthew Harlum <matt@harlum.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */
module Autoconfig (
    input [23:1] addr,
    input as_n,
    input clk,
    input rw,
    input [3:0] din,
    input reset_n,
    input ovr_detect,
    input bonus_en,
    input ide_enabled,
    input [1:0] ram_size,
    input [1:0] z2_state,
    input cfgin_n,
    input enable_maprom,
    output cfgout_n,
    output ram_access,
    output ide_access,
    output autoconfig_cycle,
    output reg [3:0] dout,
    output reg dtack,
    output reg ovl
);

`include "globalparams.vh"

// Autoconfig
localparam [15:0] mfg_id  = 16'd5194;
localparam [31:0] serial  = 32'd1;

reg ram_configured;
reg ide_configured;

reg [2:0] ide_base;
reg cdtv_configured;
reg cfgin;
reg cfgout;
reg maprom_enabled;

reg [2:0] zram_size;
reg [3:0] addr_match;
reg [1:0] ac_state;

localparam ac_ram  = 2'b00,
           ac_ide  = 2'b01,
           ac_done = 2'b10;

localparam SZ_0M = 2'b00,
           SZ_2M = 2'b01,
           SZ_4M = 2'b10,
           SZ_8M = 2'b11;

wire [7:0] prodid [0:1];

assign prodid[ac_ram] = 8'd4;
assign prodid[ac_ide] = 8'h5;

wire [3:0] boardSize [0:1];
assign boardSize[ac_ram] = {1'b1,zram_size};
assign boardSize[ac_ide] = 4'b0010; // 128K

assign autoconfig_cycle = (addr[23:16] == 8'hE8) && cfgin && !cfgout;

assign cfgout_n = ~cfgout;

// CDTV DMAC is first in chain.
// So we wait until it's configured before we talk
always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    cdtv_configured <= 0;
  end else begin
    if (addr[23:16] == 8'hE8 && addr[8:1] == 8'h24 && !as_n && !rw) begin
      cdtv_configured <= 1'b1;
    end
  end
end

// These need to be registered at the end of a bus cycle
always @(posedge as_n or negedge reset_n) begin
  if (!reset_n) begin
    cfgout <= 0;
    cfgin  <= 0;
  end else begin
`ifdef CDTV
    cfgin  <= ~cfgin_n && cdtv_configured;
`else
    cfgin  <= ~cfgin_n;
`endif
    cfgout <= (ac_state == ac_done);
  end
end

always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    zram_size <= 3'b000;
  end else begin
    case (ram_size)
      SZ_8M:   zram_size <= 3'b000;
      SZ_4M:   zram_size <= 3'b111;
      SZ_2M:   zram_size <= 3'b110;
      default: zram_size <= 3'b000;
    endcase
  end
end

always @(posedge clk or negedge reset_n)
begin
  if (!reset_n) begin
    dout           <= 'b0;
    ac_state       <= (ram_size == SZ_0M) ? (ac_ram + 1) : ac_ram;
    dtack          <= 0;
    ide_base       <= 3'b0;
    ide_configured <= 0;
    ram_configured <= 0;
    addr_match     <= 4'd0;

  end else if (z2_state == Z2_DATA && autoconfig_cycle && !dtack) begin
    dtack <= 1;
    if (rw) begin
      case (addr[8:1])
        8'h00:
          begin
            case (ac_state)
              ac_ram:  dout <= 4'b1110;                               // Memory / Link to free mem pool
              ac_ide:  dout <= {3'b110, ide_enabled};                 // IO / Read from autoboot rom
            endcase
          end
        8'h01:   dout <= {boardSize[ac_state]};                       // Size: <RAMSIZE>, 128K
        8'h02:   dout <= ~(prodid[ac_state][7:4]);                    // Product number
        8'h03:   dout <= ~(prodid[ac_state][3:0]);                    // Product number
        8'h04:   dout <= ~{ac_state == ac_ram ? 1'b1 : 1'b0, 3'b000}; // Bit 1: Add to Z2 RAM space if set
        8'h05:   dout <= ~4'b0000;
        8'h08:   dout <= ~mfg_id[15:12];                              // Manufacturer ID
        8'h09:   dout <= ~mfg_id[11:8];                               // Manufacturer ID
        8'h0A:   dout <= ~mfg_id[7:4];                                // Manufacturer ID
        8'h0B:   dout <= ~mfg_id[3:0];                                // Manufacturer ID
        8'h0C:   dout <= ~serial[31:28];                              // Serial number
        8'h0D:   dout <= ~serial[27:24];                              // Serial number
        8'h0E:   dout <= ~serial[23:20];                              // Serial number
        8'h0F:   dout <= ~serial[19:16];                              // Serial number
        8'h10:   dout <= ~serial[15:12];                              // Serial number
        8'h11:   dout <= ~serial[11:8];                               // Serial number
        8'h12:   dout <= ~serial[7:4];                                // Serial number
        8'h13:   dout <= ~serial[3:0];                                // Serial number
        8'h14:   dout <= ~4'h0;                                       // ROM Offset high byte high nibble
        8'h15:   dout <= ~4'h0;                                       // ROM Offset high byte low nibble
        8'h16:   dout <= ~4'h0;                                       // ROM Offset low byte high nibble
        8'h17:   dout <= ~4'h8;                                       // ROM Offset low byte low nibble
        8'h20:   dout <= 4'b0;
        8'h21:   dout <= 4'b0;
        default: dout <= 4'hF;
      endcase
    end else begin
      if (addr[8:1] == 8'h26) begin
          // We've been told to shut up (not enough memory space)
          ac_state <= ac_state + 1;
      end else if (addr[8:1] == 8'h24) begin
          if (ac_state == ac_ram) begin
            ram_configured <= 1'b1;
            case (ram_size)
              SZ_8M: addr_match[3:0] <= 4'b1111;
              SZ_4M:
                begin
                  case (din)
                    4'h2: addr_match[1:0] <= 2'b11;
                    4'h4: addr_match[2:1] <= 2'b11;
                    4'h6: addr_match[3:2] <= 2'b11;
                  endcase
                end
              SZ_2M:
                begin
                  case (din)
                    4'h2: addr_match[0] <= 1'b1;
                    4'h4: addr_match[1] <= 1'b1;
                    4'h6: addr_match[2] <= 1'b1;
                    4'h8: addr_match[3] <= 1'b1;
                  endcase
                end
            endcase
          end
          ac_state <= ac_state + 1;
      end else if (addr[8:1] == 8'h25) begin
          if (ac_state == ac_ide) begin
            ide_configured <= 1'b1;
            ide_base <= din[3:1];
          end
      end
    end
  end else begin
    dtack <= 0;
  end
end

always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    ovl <= 1;
    maprom_enabled <= enable_maprom && ovr_detect;
  end else begin
    if (addr[23:16] == 8'hBF && !as_n && !rw)
      ovl <= 0;
  end
end

wire   fastram_access  = (addr[23:21] == 3'b001 && addr_match[0]) || // $200000-3FFFFF
                         (addr[23:21] == 3'b010 && addr_match[1]) || // $400000-5FFFFF
                         (addr[23:21] == 3'b011 && addr_match[2]) || // $600000-7FFFFF
                         (addr[23:21] == 3'b100 && addr_match[3]);   // $800000-9FFFFF

assign ide_access      = (addr[23:17] == {4'hE, ide_base} && ide_configured);

wire bonus_access    = (addr[23:16] >= 8'hA0) && (addr[23:16] <= 8'hBD); // A00000-BDFFFF Bonus RAM

wire otherram_access = bonus_access && bonus_en && ovr_detect;

wire ranger_access   = (addr[23:16] >= 8'hC0) && (addr[23:16] <= 8'hD7) && ovr_detect;

wire bootrom_access = (addr[23:19] == 5'b00000 && ovl && maprom_enabled && rw);

wire kickrom_access = (addr[23:20] == 4'b1111 && (maprom_enabled == rw));


assign ram_access      = fastram_access && ram_configured ||
                         bootrom_access ||
                         kickrom_access ||
                         otherram_access ||
                         ranger_access;
endmodule
