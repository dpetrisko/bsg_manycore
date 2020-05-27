/**
 *  hammerblade_testbench.v
 *
 */

module hammerblade_testbench;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;

  // defines from VCS
  // rename it to something more familiar.
  parameter num_tiles_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter num_tiles_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter vcache_sets_p = `BSG_MACHINE_VCACHE_SET;
  parameter vcache_ways_p = `BSG_MACHINE_VCACHE_WAY;
  parameter vcache_block_size_in_words_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter vcache_dma_data_width_p = `BSG_MACHINE_VCACHE_DMA_DATA_WIDTH; // in bits
  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_max_epa_width_p = `BSG_MACHINE_MAX_EPA_WIDTH;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter bsg_branch_trace_en_p = `BSG_MACHINE_BRANCH_TRACE_EN;
  parameter vcache_miss_fifo_els_p = `BSG_MACHINE_VCACHE_MISS_FIFO_ELS;
  parameter int hetero_type_vec_p [0:((num_tiles_y_p-1)*num_tiles_x_p) - 1]  = '{`BSG_MACHINE_HETERO_TYPE_VEC};

  // constant params
  parameter data_width_p = 32;
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;

  parameter axi_id_width_p = 6;
  parameter axi_addr_width_p = 64;
  parameter axi_data_width_p = 256;
  parameter axi_burst_len_p = 1;

  // dmc param
  parameter dram_ctrl_addr_width_p = 29; // 512 MB

  // dramsim3 HBM2 param
  `define dram_pkg bsg_dramsim3_hbm2_8gb_x128_pkg
  parameter hbm2_data_width_p = `dram_pkg::data_width_p;
  parameter hbm2_channel_addr_width_p = `dram_pkg::channel_addr_width_p;
  parameter hbm2_num_channels_p = `dram_pkg::num_channels_p;

  // derived param
  parameter axi_strb_width_lp = (axi_data_width_p>>3);
  parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + 2);

  parameter vcache_size_p = vcache_sets_p * vcache_ways_p * vcache_block_size_in_words_p;
  parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3);
  parameter cache_addr_width_lp=(bsg_max_epa_width_p-1+byte_offset_width_lp);
  parameter data_mask_width_lp=(data_width_p>>3);

  parameter cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(bsg_dram_size_p/(2*num_tiles_x_p)*4);

  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", num_tiles_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", num_tiles_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", vcache_sets_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", vcache_ways_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", vcache_block_size_in_words_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_MISS_FIFO_ELS     = %d", vcache_miss_fifo_els_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_SIZE_WORDS          = %d", bsg_dram_size_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_INCLUDED            = %d", bsg_dram_included_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", bsg_max_epa_width_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_manycore_mem_cfg_p.name());
  end


  // clock and reset generation
  //
  parameter core_clk_period_p = 1000; // 1000 ps == 1 GHz

  bit core_clk;
  bit reset;

  bsg_nonsynth_clock_gen #(
    .cycle_time_p(core_clk_period_p)
  ) clock_gen (
    .o(core_clk)
  );

  bsg_nonsynth_reset_gen #(
    .num_clocks_p(1)
    ,.reset_cycles_lo_p(0)
    ,.reset_cycles_hi_p(16)
  ) reset_gen (
    .clk_i(core_clk)
    ,.async_reset_o(reset)
  );


  // bsg_manycore has 3 flops that reset signal needs to go through.
  // So we are trying to match that here.
  logic [2:0] reset_r;

  always_ff @ (posedge core_clk) begin
    reset_r[0] <= reset;
    reset_r[1] <= reset_r[0];
    reset_r[2] <= reset_r[1];
  end


  // instantiate manycore
  //
  `declare_bsg_manycore_link_sif_s(bsg_max_epa_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp);

  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_li, ver_link_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0] hor_link_li, hor_link_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_li, io_link_lo;

  bsg_manycore #(
    .dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.branch_trace_en_p(bsg_branch_trace_en_p)
    ,.hetero_type_vec_p(hetero_type_vec_p)
  ) manycore (
    .clk_i(core_clk)
    ,.reset_i(reset)

    ,.hor_link_sif_i(hor_link_li)
    ,.hor_link_sif_o(hor_link_lo)

    ,.ver_link_sif_i(ver_link_li)
    ,.ver_link_sif_o(ver_link_lo)

    ,.io_link_sif_i(io_link_li)
    ,.io_link_sif_o(io_link_lo)
  );

  assign ver_link_li = '0;

  initial begin
    #100000;
    $display("Test over");
    $finish();
  end

  // Hardcoded from bp_unicore_cfg
  localparam cce_mem_msg_width_lp = 572;
  logic [cce_mem_msg_width_lp-1:0] proc_mem_cmd_lo;
  logic proc_mem_cmd_v_lo, proc_mem_cmd_ready_li;
  logic [cce_mem_msg_width_lp-1:0] proc_mem_resp_li;
  logic proc_mem_resp_v_li, proc_mem_resp_yumi_lo;

  logic [cce_mem_msg_width_lp-1:0] proc_io_cmd_lo;
  logic proc_io_cmd_v_lo, proc_io_cmd_ready_li;
  logic [cce_mem_msg_width_lp-1:0] proc_io_resp_li;
  logic proc_io_resp_v_li, proc_io_resp_yumi_lo;

  logic [cce_mem_msg_width_lp-1:0] proc_io_cmd_li;
  logic proc_io_cmd_v_li, proc_io_cmd_yumi_lo;
  logic [cce_mem_msg_width_lp-1:0] proc_io_resp_lo;
  logic proc_io_resp_v_lo, proc_io_resp_ready_li;

  bp_unicore #(
    .bp_params_p(2) //e_bp_unicore_cfg
  ) blackparrot (
    .clk_i(core_clk)
    ,.reset_i(reset)

    ,.io_cmd_o(proc_io_cmd_lo)
    ,.io_cmd_v_o(proc_io_cmd_v_lo)
    ,.io_cmd_ready_i(proc_io_cmd_ready_li)

    ,.io_resp_i(proc_io_resp_li)
    ,.io_resp_v_i(proc_io_resp_v_li)
    ,.io_resp_yumi_o(proc_io_resp_yumi_lo)

    ,.io_cmd_i(proc_io_cmd_li)
    ,.io_cmd_v_i(proc_io_cmd_v_li)
    ,.io_cmd_yumi_o(proc_io_cmd_yumi_lo)

    ,.io_resp_o(proc_io_resp_lo)
    ,.io_resp_v_o(proc_io_resp_v_lo)
    ,.io_resp_ready_i(proc_io_resp_ready_li)

    ,.mem_cmd_o(proc_mem_cmd_lo)
    ,.mem_cmd_v_o(proc_mem_cmd_v_lo)
    ,.mem_cmd_ready_i(proc_mem_cmd_ready_li)

    ,.mem_resp_i(proc_mem_resp_li)
    ,.mem_resp_v_i(proc_mem_resp_v_li)
    ,.mem_resp_yumi_o(proc_mem_resp_yumi_lo)
    );

  bp_cce_to_mc 
   #(.bp_params_p(2)
     ,.mc_x_cord_width_p(x_cord_width_lp)
     ,.mc_y_cord_width_p(y_cord_width_lp)
     ,.mc_data_width_p(data_width_p)
     ,.mc_addr_width_p(bsg_max_epa_width_p)
     )
   cce_to_mc
    (.clk_i(core_clk)
     ,.reset_i(reset)

     ,.io_cmd_i(proc_io_cmd_lo)
     ,.io_cmd_v_i(proc_io_cmd_v_lo)
     ,.io_cmd_ready_o(proc_io_cmd_ready_li)

     ,.io_resp_o(proc_io_resp_li)
     ,.io_resp_v_o(proc_io_resp_v_li)
     ,.io_resp_yumi_i(proc_io_resp_yumi_lo)

     ,.io_cmd_o(proc_io_cmd_li)
     ,.io_cmd_v_o(proc_io_cmd_v_li)
     ,.io_cmd_yumi_i(proc_io_cmd_yumi_lo)

     ,.io_resp_i(proc_io_resp_lo)
     ,.io_resp_v_i(proc_io_resp_v_lo)
     ,.io_resp_ready_o(proc_io_resp_ready_li)

     ,.link_sif_i(io_link_lo[0])
     ,.link_sif_o(io_link_li[0])
     );

  bp_mem #(
    .bp_params_p(2) //e_bp_unicore_cfg
    ,.mem_cap_in_bytes_p(2**28)
    ,.mem_load_p(1)
    ,.mem_zero_p(1)
    ,.mem_file_p("manycore_poke.mem")
    ,.mem_offset_p(32'h8000_0000)
  
    ,.use_max_latency_p(1)
    ,.use_random_latency_p(0)
    ,.use_dramsim2_latency_p(0)
    ,.max_latency_p(20)
  
    ,.dram_clock_period_in_ps_p(0)
    ,.dram_cfg_p(0)
    ,.dram_sys_cfg_p(0)
    ,.dram_capacity_p(0)
  ) mem (
    .clk_i(core_clk)
    ,.reset_i(reset)
  
    ,.mem_cmd_i(proc_mem_cmd_lo)
    ,.mem_cmd_v_i(proc_mem_cmd_v_lo)
    ,.mem_cmd_ready_o(proc_mem_cmd_ready_li)
  
    ,.mem_resp_o(proc_mem_resp_li)
    ,.mem_resp_v_o(proc_mem_resp_v_li)
    ,.mem_resp_yumi_i(proc_mem_resp_yumi_lo)
    );

  // global counter
  //
  logic [31:0] global_ctr;

  bsg_cycle_counter global_cc (
    .clk_i(core_clk)
    ,.reset_i(reset_r[2])
    ,.ctr_r_o(global_ctr)
  );

  // tieoffs
  //
  for (genvar i = 0; i < num_tiles_y_p; i++) begin: we_tieoff

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_w (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(hor_link_lo[W][i])
      ,.link_sif_o(hor_link_li[W][i])
    );

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_e (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end

  for (genvar i = 1; i < num_tiles_x_p; i++) begin: io_tieoff
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_io (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(io_link_lo[i])
      ,.link_sif_o(io_link_li[i])
    );
  end

endmodule

