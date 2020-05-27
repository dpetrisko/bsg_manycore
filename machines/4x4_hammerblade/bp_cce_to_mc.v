
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
 
     , parameter mc_x_cord_width_p = "inv"
     , parameter mc_y_cord_width_p = "inv"
     , parameter mc_data_width_p   = "inv"
     , parameter mc_addr_width_p   = "inv"
     , localparam mc_packet_width_lp = `bsg_manycore_packet_width(mc_addr_width_p, mc_data_width_p, mc_x_cord_width_p, mc_y_cord_width_p)

     , localparam mc_link_sif_width_lp = `bsg_manycore_link_sif_width(mc_addr_width_p, mc_data_width_p, mc_x_cord_width_p, mc_y_cord_width_p)
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
  logic                              returned_yumi_li;
  logic                              returned_fifo_full_lo;

  logic [`BSG_SAFE_CLOG2(16)-1:0]    out_credits_lo;
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
    ,.returned_yumi_i(returned_yumi_li)
    ,.returned_fifo_full_o(returned_fifo_full_lo)

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i(0)
    ,.my_y_i(1)
    );


  // BP signals
  assign io_cmd_o = cfg_cmd_lo;
  assign io_cmd_v_o = cfg_cmd_v_lo;
  assign cfg_cmd_yumi_li = io_cmd_yumi_i;

  assign cfg_resp_li = io_resp_i;
  assign cfg_resp_v_li = io_resp_v_i;
  assign io_resp_ready_o = cfg_resp_ready_lo;

  assign io_cmd_ready_o = 1'b1;

  assign io_resp_v_o = '0;
  assign io_resp_o = '0;

  // Manycore signals
  assign in_yumi_li = '0;
  assign returning_data_li = '0;
  assign returning_v_li = '0;

  assign out_v_li = '0;
  assign out_packet_li = '0;

  assign returned_yumi_li = '0;

endmodule

