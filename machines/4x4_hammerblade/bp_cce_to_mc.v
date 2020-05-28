
module bp_cce_to_mc
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
     `declare_bp_proc_params(bp_params_p)
     `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
 
     , parameter mc_x_cord_width_p        = "inv"
     , parameter mc_y_cord_width_p        = "inv"
     , parameter mc_data_width_p          = "inv"
     , parameter mc_addr_width_p          = "inv"
     , localparam mc_packet_width_lp      = `bsg_manycore_packet_width(mc_addr_width_p, mc_data_width_p, mc_x_cord_width_p, mc_y_cord_width_p)

     , localparam mc_link_sif_width_lp    = `bsg_manycore_link_sif_width(mc_addr_width_p, mc_data_width_p, mc_x_cord_width_p, mc_y_cord_width_p)

     , localparam mc_max_outstanding_p = 32

     , localparam [mc_x_cord_width_p-1:0] bp_x_cord_lp = mc_x_cord_width_p'(0)
     , localparam [mc_y_cord_width_p-1:0] bp_y_cord_lp = mc_y_cord_width_p'(1)
    )
   (input                                      clk_i
    , input                                    reset_i

    , input [cce_mem_msg_width_lp-1:0]         io_cmd_i
    , input                                    io_cmd_v_i
    , output logic                             io_cmd_ready_o

    , output logic [cce_mem_msg_width_lp-1:0]  io_resp_o
    , output logic                             io_resp_v_o
    , input                                    io_resp_yumi_i

    , output logic [cce_mem_msg_width_lp-1:0]  io_cmd_o
    , output logic                             io_cmd_v_o
    , input                                    io_cmd_yumi_i

    , input [cce_mem_msg_width_lp-1:0]         io_resp_i
    , input                                    io_resp_v_i
    , output                                   io_resp_ready_o

    , input [mc_link_sif_width_lp-1:0]         link_sif_i
    , output [mc_link_sif_width_lp-1:0]        link_sif_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bsg_manycore_packet_s(mc_addr_width_p, mc_data_width_p, mc_x_cord_width_p, mc_y_cord_width_p);

  bp_cce_mem_msg_s io_cmd_cast_i, io_resp_cast_o;
  bp_cce_mem_msg_s io_cmd_cast_o, io_resp_cast_i;

  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;
  assign io_cmd_o = io_cmd_cast_o;
  assign io_resp_cast_i = io_resp_i;

  bp_cce_mem_msg_s cfg_cmd_lo;
  logic cfg_cmd_v_lo, cfg_cmd_yumi_li;
  bp_cce_mem_msg_s cfg_resp_li;
  logic cfg_resp_v_li, cfg_resp_ready_lo;
  logic cfg_done_lo;
  bp_cce_mmio_cfg_loader
    #(.bp_params_p(2)
      ,.inst_width_p(34)
      ,.inst_ram_addr_width_p(8)
      ,.inst_ram_els_p(256)
      ,.skip_ram_init_p(0)
      ,.clear_freeze_p(1)
      )
    cfg_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.lce_id_i(4'('b10))
  
     ,.io_cmd_o(cfg_cmd_lo)
     ,.io_cmd_v_o(cfg_cmd_v_lo)
     ,.io_cmd_yumi_i(cfg_cmd_yumi_li)
  
     ,.io_resp_i(cfg_resp_li)
     ,.io_resp_v_i(cfg_resp_v_li)
     ,.io_resp_ready_o(cfg_resp_ready_lo)
  
     ,.done_o(cfg_done_lo)
    );

  logic                              in_v_lo;
  logic [mc_data_width_p-1:0]        in_data_lo;
  logic [(mc_data_width_p>>3)-1:0]   in_mask_lo;
  logic [mc_addr_width_p-1:0]        in_addr_lo;
  logic                              in_we_lo;
  bsg_manycore_load_info_s           in_load_info_lo;
  logic [mc_x_cord_width_p-1:0]      in_src_x_cord_lo;
  logic [mc_y_cord_width_p-1:0]      in_src_y_cord_lo;
  logic                              in_yumi_li;

  logic [mc_data_width_p-1:0]        returning_data_li;
  logic                              returning_v_li;

  logic                              out_v_li;
  bsg_manycore_packet_s              out_packet_li;
  logic                              out_ready_lo;

  logic [mc_data_width_p-1:0]        returned_data_r_lo;
  logic [4:0]                        returned_reg_id_r_lo;
  logic                              returned_v_r_lo;
  bsg_manycore_return_packet_type_e  returned_pkt_type_r_lo;
  logic                              returned_fifo_full_lo;
  logic                              returned_credit_v_r_lo;
  logic [4:0]                        returned_credit_reg_id_r_lo;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(mc_x_cord_width_p)
    ,.y_cord_width_p(mc_y_cord_width_p)
    ,.fifo_els_p(16)
    ,.data_width_p(mc_data_width_p)
    ,.addr_width_p(mc_addr_width_p)

    ,.max_out_credits_p(16)
    ,.warn_out_of_credits_p(0)
    ,.debug_p(1)
  ) blackparrot_endpoint (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    //--------------------------------------------------------
    // 1. in_request signal group
    ,.in_v_o(in_v_lo)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_we_o(in_we_lo)
    ,.in_load_info_o(in_load_info_lo)
    ,.in_src_x_cord_o(in_src_x_cord_lo)
    ,.in_src_y_cord_o(in_src_y_cord_lo)
    ,.in_yumi_i(in_yumi_li)

    //--------------------------------------------------------
    // 2. out_response signal group
    //    responses that will send back to the network
    ,.returning_data_i(returning_data_li)
    ,.returning_v_i(returning_v_li)

    //--------------------------------------------------------
    // 3. out_request signal group
    //    request that will send to the network
    ,.out_v_i(out_v_li)
    ,.out_packet_i(out_packet_li)
    ,.out_ready_o(out_ready_lo)

    //--------------------------------------------------------
    // 4. in_response signal group
    //    responses that send back from the network
    //    the node shold always be ready to receive this response.
    ,.returned_data_r_o(returned_data_r_lo)
    ,.returned_reg_id_r_o(returned_reg_id_r_lo)
    ,.returned_v_r_o(returned_v_r_lo)
    ,.returned_pkt_type_r_o(returned_pkt_type_r_lo)
    // We allocate data in the return fifo, so we can immediately accept, always
    ,.returned_yumi_i(returned_v_r_lo)
    ,.returned_fifo_full_o()

    ,.returned_credit_v_r_o(returned_credit_v_r_lo)
    ,.returned_credit_reg_id_r_o(returned_credit_reg_id_r_lo)

    ,.out_credits_o()

    ,.my_x_i(bp_x_cord_lp)
    ,.my_y_i(bp_y_cord_lp)
    );

  // BP bootstrapping 
  assign io_cmd_cast_o = cfg_cmd_lo;
  assign io_cmd_v_o = cfg_cmd_v_lo;
  assign cfg_cmd_yumi_li = io_cmd_yumi_i;

  assign cfg_resp_li = io_resp_cast_i;
  assign cfg_resp_v_li = io_resp_v_i;
  assign io_resp_ready_o = cfg_resp_ready_lo;

  //
  // TX
  //
  logic [`BSG_SAFE_CLOG2(mc_max_outstanding_p)-1:0] trans_id_lo;
  logic trans_id_v_lo, trans_id_yumi_li;
  logic [mc_data_width_p-1:0] load_data_lo;
  logic load_data_v_lo, load_data_yumi_li;
  bsg_fifo_reorder
   #(.width_p(mc_data_width_p), .els_p(mc_max_outstanding_p))
   return_data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.fifo_alloc_id_o(trans_id_lo)
     ,.fifo_alloc_v_o(trans_id_v_lo)
     ,.fifo_alloc_yumi_i(trans_id_yumi_li)

     // We write an entry on credit return in order to determine when to send
     //   back a store response.  A little inefficent, but allocating storage for
     //   worst case (all loads) isn't unreasonable
     ,.write_id_i(returned_v_r_lo ? returned_reg_id_r_lo : returned_credit_reg_id_r_lo)
     ,.write_data_i(returned_data_r_lo)
     ,.write_v_i(returned_v_r_lo | returned_credit_v_r_lo)

     ,.fifo_deq_data_o(load_data_lo)
     ,.fifo_deq_v_o(load_data_v_lo)
     ,.fifo_deq_yumi_i(load_data_yumi_li)

     ,.empty_o()
     );
  assign trans_id_yumi_li  = io_cmd_v_i;
  assign load_data_yumi_li = io_resp_yumi_i;

  bp_cce_mem_msg_header_s io_resp_header_lo;
  logic io_resp_header_v_lo, io_resp_header_yumi_li;
  logic header_ready_lo;
  bsg_fifo_1r1w_small
   #(.width_p($bits(io_cmd_cast_i.header)), .els_p(mc_max_outstanding_p))
   return_header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(io_cmd_cast_i.header)
     ,.v_i(io_cmd_v_i)
     ,.ready_o(header_ready_lo)

     ,.data_o(io_resp_header_lo)
     ,.v_o(io_resp_header_v_lo)
     ,.yumi_i(io_resp_header_yumi_li)
     );
  assign io_resp_header_yumi_li = io_resp_yumi_i;

  typedef struct packed
  {
    logic dram_not_tile;
    logic tile_not_dram;
    union packed
    {
      struct packed
      {
        logic [29:0] dram_addr;
      } dram_eva;
      struct packed
      {
        logic [max_y_cord_width_gp-1:0]    y_cord;
        logic [max_x_cord_width_gp-1:0]    x_cord;
        logic [epa_word_addr_width_gp-1:0] epa;
        logic [1:0]                        low_bits;
      } tile_eva;
    } a;
  } bp_eva_s;

  bp_eva_s io_cmd_eva_li;
  assign io_cmd_eva_li = io_cmd_cast_i.header.addr;

  // Command packet formation
  always_comb
    begin
      io_cmd_ready_o = trans_id_v_lo & header_ready_lo & out_ready_lo;
      out_v_li = io_cmd_v_i;

      case (io_cmd_cast_i.header.msg_type)
        e_cce_mem_uc_rd:
          begin
            // Word-aligned address
            out_packet_li.addr                             = io_cmd_eva_li.a.tile_eva.epa;
            out_packet_li.op                               = e_remote_load;
            // Ignored for remote loads
            out_packet_li.op_ex                            = '0;
            // Overload reg_id with the trans id of the request
            out_packet_li.reg_id                           = bsg_manycore_reg_id_width_gp'(trans_id_lo);
            // Irrelevant for bp loads
            out_packet_li.payload.load_info_s.load_info.float_wb       = '0;
            out_packet_li.payload.load_info_s.load_info.icache_fetch   = '0;
            out_packet_li.payload.load_info_s.load_info.is_unsigned_op = '0;
            // 64-bit+ packets are not supported
            out_packet_li.payload.load_info_s.load_info.is_byte_op     = (io_cmd_cast_i.header.size == e_mem_msg_size_1);
            out_packet_li.payload.load_info_s.load_info.is_hex_op      = (io_cmd_cast_i.header.size == e_mem_msg_size_2);
            // Assume aligned for now
            out_packet_li.payload.load_info_s.load_info.part_sel       = io_cmd_eva_li.a.tile_eva.low_bits;
            out_packet_li.src_y_cord                       = bp_y_cord_lp;
            out_packet_li.src_x_cord                       = bp_x_cord_lp;
            out_packet_li.y_cord                           = io_cmd_eva_li.a.tile_eva.y_cord;
            out_packet_li.x_cord                           = io_cmd_eva_li.a.tile_eva.x_cord;
          end
        e_cce_mem_uc_wr:
          begin
            // Word-aligned address
            out_packet_li.addr                             = io_cmd_eva_li.a.tile_eva.epa;
            out_packet_li.op                               = e_remote_store;
            // Set store data and mask (assume aligned)
            case (io_cmd_cast_i.header.size)
              e_mem_msg_size_1:
                begin
                  out_packet_li.payload.data               = {4{io_cmd_cast_i.data[0+:8]}};
                  out_packet_li.op_ex.store_mask           = 4'h1 << io_cmd_eva_li.a.tile_eva.low_bits;
                end
              e_mem_msg_size_2:
                begin
                  out_packet_li.payload.data               = {2{io_cmd_cast_i.data[0+:16]}};
                  out_packet_li.op_ex.store_mask           = 4'h3 << io_cmd_eva_li.a.tile_eva.low_bits;
                end
              e_mem_msg_size_4:
                begin
                  out_packet_li.payload.data               = {1{io_cmd_cast_i.data[0+:32]}};
                  out_packet_li.op_ex.store_mask           = 4'hf << io_cmd_eva_li.a.tile_eva.low_bits;
                end
              default:
                begin
                  // Should not happen
                  out_packet_li.payload.data               = '0;
                  out_packet_li.op_ex.store_mask           = '0;
                end
            endcase
            out_packet_li.reg_id                           = bsg_manycore_reg_id_width_gp'(trans_id_lo);
            out_packet_li.src_y_cord                       = bp_y_cord_lp;
            out_packet_li.src_x_cord                       = bp_x_cord_lp;
            out_packet_li.y_cord                           = io_cmd_eva_li.a.tile_eva.y_cord;
            out_packet_li.x_cord                           = io_cmd_eva_li.a.tile_eva.x_cord;
          end
        // Unsupported
        e_cce_mem_pre
        ,e_cce_mem_rd
        ,e_cce_mem_wr: out_packet_li = '0;
        default      : out_packet_li = '0;
      endcase
    end

  // Response packet formation
  always_comb
    begin
     io_resp_v_o = io_resp_header_v_lo & load_data_v_lo;

     io_resp_cast_o.header = io_resp_header_lo;
     io_resp_cast_o.data   = load_data_lo;
    end

  //
  // RX (stubbed)
  //
  assign in_yumi_li = '0;
  assign returning_data_li = '0;
  assign returning_v_li = '0;

  always_ff @(negedge clk_i)
    begin
      if (io_cmd_v_i)
        $display("[BP] Incoming command: %p", io_cmd_cast_i);
      if (out_v_li)
        $display("[LINK] Outgoing mc_pkt: %p", out_packet_li);
      if (io_resp_yumi_i)
        $display("[BP] Outgoing response: %p", io_resp_cast_o);
    end

endmodule

