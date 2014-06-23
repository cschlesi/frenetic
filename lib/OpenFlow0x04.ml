(* TODO(???): rename sizeof to size_of for consistency with 0x01 stuff. *)

(** OpenFlow 1.3 (protocol version 0x04) *)

open Printf
open Cstruct
open Cstruct.BE
open OpenFlow0x04_Core
open List
open Packet

exception Unparsable of string
let sym_num = ref 0

let sum (lst : int list) = List.fold_left (fun x y -> x + y) 0 lst

type uint48 = uint64
type uint12 = uint16
type switchId = OpenFlow0x04_Core.switchId

(* OKAY *)
cenum msg_code {
  HELLO;
  ERROR;
  ECHO_REQ;
  ECHO_RESP;
  VENDOR;
  FEATURES_REQ;
  FEATURES_RESP;
  GET_CONFIG_REQ;
  GET_CONFIG_RESP;
  SET_CONFIG;
  PACKET_IN;
  FLOW_REMOVED;
  PORT_STATUS;
  PACKET_OUT;
  FLOW_MOD;
  GROUP_MOD;
  PORT_MOD;
  TABLE_MOD;
  MULTIPART_REQ;
  MULTIPART_RESP;
  BARRIER_REQ;
  BARRIER_RESP;
  QUEUE_GET_CONFIG_REQ;
  QUEUE_GET_CONFIG_RESP;
  ROLE_REQ;
  ROLE_RESP;
  GET_ASYNC_REQ;
  GET_ASYNC_REP;
  SET_ASYNC;
  METER_MOD
} as uint8_t

cstruct ofp_match {
  uint16_t typ;          
  uint16_t length
} as big_endian

let ofpp_in_port = 0xfffffff8l
let ofpp_flood = 0xfffffffbl
let ofpp_all = 0xfffffffcl
let ofpp_controller = 0xfffffffdl
let ofpp_any = 0xffffffffl

let ofp_no_buffer = 0xffffffffl

(* Not in the spec, comes from C headers. :rolleyes: *)
let ofpg_all = 0xfffffffcl
let ofpg_any = 0xffffffffl
let ofp_eth_alen = 6          (* Bytes in an Ethernet address. *)

(* OKAY *)
cenum ofp_oxm_class {
  OFPXMC_NXM_0          = 0x0000;    (* Backward compatibility with NXM *)
  OFPXMC_NXM_1          = 0x0001;    (* Backward compatibility with NXM *)
  OFPXMC_OPENFLOW_BASIC = 0x8000;    (* Basic class for OpenFlow *)
  OFPXMC_EXPERIMENTER   = 0xFFFF     (* Experimenter class *)
} as uint16_t

(* OKAY *)
cenum oxm_ofb_match_fields {
  OFPXMT_OFB_IN_PORT        = 0;  (* Switch input port. *)
  OFPXMT_OFB_IN_PHY_PORT    = 1;  (* Switch physical input port. *)
  OFPXMT_OFB_METADATA       = 2;  (* Metadata passed between tables. *)
  OFPXMT_OFB_ETH_DST        = 3;  (* Ethernet destination address. *)
  OFPXMT_OFB_ETH_SRC        = 4;  (* Ethernet source address. *)
  OFPXMT_OFB_ETH_TYPE       = 5;  (* Ethernet frame type. *)
  OFPXMT_OFB_VLAN_VID       = 6;  (* VLAN id. *)
  OFPXMT_OFB_VLAN_PCP       = 7;  (* VLAN priority. *)
  OFPXMT_OFB_IP_DSCP        = 8;  (* IP DSCP (6 bits in ToS field). *)
  OFPXMT_OFB_IP_ECN         = 9;  (* IP ECN (2 bits in ToS field). *)
  OFPXMT_OFB_IP_PROTO       = 10; (* IP protocol. *)
  OFPXMT_OFB_IPV4_SRC       = 11; (* IPv4 source address. *)
  OFPXMT_OFB_IPV4_DST       = 12; (* IPv4 destination address. *)
  OFPXMT_OFB_TCP_SRC        = 13; (* TCP source port. *)
  OFPXMT_OFB_TCP_DST        = 14; (* TCP destination port. *)
  OFPXMT_OFB_UDP_SRC        = 15; (* UDP source port. *)
  OFPXMT_OFB_UDP_DST        = 16; (* UDP destination port. *)
  OFPXMT_OFB_SCTP_SRC       = 17; (* SCTP source port. *)
  OFPXMT_OFB_SCTP_DST       = 18; (* SCTP destination port. *)
  OFPXMT_OFB_ICMPV4_TYPE    = 19; (* ICMP type. *)
  OFPXMT_OFB_ICMPV4_CODE    = 20; (* ICMP code. *)
  OFPXMT_OFB_ARP_OP         = 21; (* ARP opcode. *)
  OFPXMT_OFB_ARP_SPA        = 22; (* ARP source IPv4 address. *)
  OFPXMT_OFB_ARP_TPA        = 23; (* ARP target IPv4 address. *)
  OFPXMT_OFB_ARP_SHA        = 24; (* ARP source hardware address. *)
  OFPXMT_OFB_ARP_THA        = 25; (* ARP target hardware address. *)
  OFPXMT_OFB_IPV6_SRC       = 26; (* IPv6 source address. *)
  OFPXMT_OFB_IPV6_DST       = 27; (* IPv6 destination address. *)
  OFPXMT_OFB_IPV6_FLABEL    = 28; (* IPv6 Flow Label *)
  OFPXMT_OFB_ICMPV6_TYPE    = 29; (* ICMPv6 type. *)
  OFPXMT_OFB_ICMPV6_CODE    = 30; (* ICMPv6 code. *)
  OFPXMT_OFB_IPV6_ND_TARGET = 31; (* Target address for ND. *)
  OFPXMT_OFB_IPV6_ND_SLL    = 32; (* Source link-layer for ND. *)
  OFPXMT_OFB_IPV6_ND_TLL    = 33; (* Target link-layer for ND. *)
  OFPXMT_OFB_MPLS_LABEL     = 34; (* MPLS label. *)
  OFPXMT_OFB_MPLS_TC        = 35; (* MPLS TC. *)
  OFPXMT_OFP_MPLS_BOS       = 36; (* MPLS BoS bit. *)
  OFPXMT_OFB_PBB_ISID       = 37; (* PBB I-SID. *)
  OFPXMT_OFB_TUNNEL_ID      = 38; (* Logical Port Metadata. *)
  OFPXMT_OFB_IPV6_EXTHDR    = 39  (* IPv6 Extension Header pseudo-field *)
} as uint8_t

cenum ofp_vlan_id {
  OFPVID_PRESENT = 0x1000; (* Bit that indicate that a VLAN id is set *)
  OFPVID_NONE    = 0x0000  (* No VLAN id was set. *)
} as uint16_t

cstruct ofp_switch_features {
  uint64_t datapath_id;
  uint32_t n_buffers;
  uint8_t n_tables;
  uint8_t auxiliary_id;
  uint8_t pad0;
  uint8_t pad1;
  uint8_t pad2;
  uint32_t capabilities; 
  uint32_t reserved
} as big_endian 

module PortConfig = struct

  let config_to_int (config : portConfig) : int32 =
    Int32.logor (if config.port_down then (Int32.shift_left 1l 0) else 0l) 
     (Int32.logor (if config.no_recv then (Int32.shift_left 1l 2) else 0l)  
      (Int32.logor (if config.no_fwd then (Int32.shift_left 1l 5) else 0l)
       (if config.no_packet_in then (Int32.shift_left 1l 6) else 0l)))

  let marshal (pc : portConfig) : int32 = config_to_int pc
		

  let parse bits : portConfig =
    { port_down     = Bits.test_bit 0 bits;
      no_recv       = Bits.test_bit 2 bits;
      no_fwd        = Bits.test_bit 5 bits;
      no_packet_in  = Bits.test_bit 6 bits
    }

  let to_string (config : portConfig) = 
    Format.sprintf "port_down:%b,no_recv:%b,no_fwd:%b,no_packet_in:%b"
    config.port_down
    config.no_recv
    config.no_fwd
    config.no_packet_in
end

module PortFeatures = struct

  let features_to_int (features : portFeatures) : int32 =
    Int32.logor (if features.rate_10mb_hd then (Int32.shift_left 1l 0) else 0l)
    (Int32.logor (if features.rate_10mb_fd then (Int32.shift_left 1l 1) else 0l)
     (Int32.logor (if features.rate_100mb_hd then (Int32.shift_left 1l 2) else 0l)
      (Int32.logor (if features.rate_100mb_fd then (Int32.shift_left 1l 3) else 0l)
       (Int32.logor (if features.rate_1gb_hd then (Int32.shift_left 1l 4) else 0l)
        (Int32.logor (if features.rate_1gb_fd then (Int32.shift_left 1l 5) else 0l)
         (Int32.logor (if features.rate_10gb_fd then (Int32.shift_left 1l 6) else 0l)
          (Int32.logor (if features.rate_40gb_fd then (Int32.shift_left 1l 7) else 0l)
           (Int32.logor (if features.rate_100gb_fd then (Int32.shift_left 1l 8) else 0l)
            (Int32.logor (if features.rate_1tb_fd then (Int32.shift_left 1l 9) else 0l)
             (Int32.logor (if features.other then (Int32.shift_left 1l 10) else 0l)
              (Int32.logor (if features.copper then (Int32.shift_left 1l 11) else 0l)
               (Int32.logor (if features.fiber then (Int32.shift_left 1l 12) else 0l)
                (Int32.logor (if features.autoneg then (Int32.shift_left 1l 13) else 0l)
                 (Int32.logor (if features.pause then (Int32.shift_left 1l 14) else 0l)
                  (if features.pause_asym then (Int32.shift_left 1l 15) else 0l)))))))))))))))

  let marshal (pf : portFeatures) : int32 = features_to_int pf

  let parse bits : portFeatures =
    { rate_10mb_hd  = Bits.test_bit 0 bits;
      rate_10mb_fd  = Bits.test_bit 1 bits;
      rate_100mb_hd = Bits.test_bit 2 bits;
      rate_100mb_fd = Bits.test_bit 3 bits;
      rate_1gb_hd   = Bits.test_bit 4 bits;
      rate_1gb_fd   = Bits.test_bit 5 bits;
      rate_10gb_fd  = Bits.test_bit 6 bits;
      rate_40gb_fd  = Bits.test_bit 7 bits;
      rate_100gb_fd = Bits.test_bit 8 bits;
      rate_1tb_fd   = Bits.test_bit 9 bits;
      other         = Bits.test_bit 10 bits;
      copper        = Bits.test_bit 11 bits;
      fiber         = Bits.test_bit 12 bits;
      autoneg       = Bits.test_bit 13 bits;
      pause         = Bits.test_bit 14 bits;
      pause_asym    = Bits.test_bit 15 bits
    }

  let to_string (feat : portFeatures) =
    Format.sprintf
      "10mhd:%b,10mfd:%b,100mhd:%b,100mfd:%b,1ghd%b\
      1gfd:%b,10gfd:%b,40gfd:%b,100gfd:%b,1tfd:%b,\
      other:%b,copper:%b,fiber:%b,autoneg:%b,pause:%b,\
      pause_asym:%b"
      feat.rate_10mb_hd
      feat.rate_10mb_fd
      feat.rate_100mb_hd
      feat.rate_100mb_fd
      feat.rate_1gb_hd
      feat.rate_1gb_fd
      feat.rate_10gb_fd
      feat.rate_40gb_fd
      feat.rate_100gb_fd
      feat.rate_1tb_fd
      feat.other
      feat.copper
      feat.fiber
      feat.autoneg
      feat.pause
      feat.pause_asym
end

cstruct ofp_port_stats_request {
  uint32_t port_no;
  uint8_t pad[4]
} as big_endian

cstruct ofp_queue_stats_request {
  uint32_t port_no;
  uint32_t queue_id
} as big_endian

cstruct ofp_group_stats_request {
  uint32_t group_id;
  uint8_t pad[4]
} as big_endian

cstruct ofp_meter_multipart_request {
  uint32_t meter_id;
  uint8_t pad[4]
} as big_endian

cstruct ofp_table_features {
  uint16_t length;
  uint8_t table_id;
  uint8_t pad[5];
  uint8_t name[32];
  uint64_t metadata_match;
  uint64_t metadata_write;
  uint32_t config; 
  uint32_t max_entries
} as big_endian

(* Body of reply to OFPMP_PORT request. If a counter is unsupported, set
* the field to all ones. *)
cstruct ofp_port_stats {
  uint32_t port_no;
  uint8_t pad[4]; (* Align to 64-bits. *)
  uint64_t rx_packets; (* Number of received packets. *)
  uint64_t tx_packets; (* Number of transmitted packets. *)
  uint64_t rx_bytes; (* Number of received bytes. *)
  uint64_t tx_bytes; (* Number of transmitted bytes. *)
  uint64_t rx_dropped; (* Number of packets dropped by RX. *)
  uint64_t tx_dropped; (* Number of packets dropped by TX. *)
  uint64_t rx_errors; (* Number of receive errors. This is a super-set
			 of more specific receive errors and should be
			 greater than or equal to the sum of all
			 rx_*_err values. *)
  uint64_t tx_errors; (* Number of transmit errors. This is a super-set
			 of more specific transmit errors and should be
			 greater than or equal to the sum of all
			 tx_*_err values (none currently defined.) *)
  uint64_t rx_frame_err; (* Number of frame alignment errors. *)
  uint64_t rx_over_err; (* Number of packets with RX overrun. *)
  uint64_t rx_crc_err; (* Number of CRC errors. *)
  uint64_t collisions; (* Number of collisions. *)
  uint32_t duration_sec; (* Time port has been alive in seconds. *)
  uint32_t duration_nsec (* Time port has been alive in nanoseconds beyond
			     duration_sec. *)
} as big_endian

cstruct ofp_port {
  uint32_t port_no;
  uint32_t pad;
  uint8_t hw_addr[6];
  uint8_t pad2;
  uint8_t pad3;
  uint8_t name[16]; (* OFP_MAX_PORT_NAME_LEN, Null-terminated *)
  uint32_t config; (* Bitmap of OFPPC_* flags. *)
  uint32_t state; (* Bitmap of OFPPS_* flags. *)
  (* Bitmaps of OFPPF_* that describe features. All bits zeroed if
   * unsupported or unavailable. *)
  uint32_t curr; (* Current features. *)
  uint32_t advertised; (* Features being advertised by the port. *)
  uint32_t supported; (* Features supported by the port. *)
  uint32_t peer; (* Features advertised by peer. *)
  uint32_t curr_speed; (* Current port bitrate in kbps. *)
  uint32_t max_speed (* Max port bitrate in kbps *)
} as big_endian

cenum ofp_port_reason {
  OFPPR_ADD;
  OFPPR_DELETE;
  OFPPR_MODIFY
} as uint8_t

cstruct ofp_port_status {
  uint8_t reason;               (* One of OFPPR_* *)
  uint8_t pad[7]
} as big_endian

cenum ofp_table_config {
  OFPTC_DEPRECATED_MASK = 0x00000003l (* currently deprecated *)
} as uint32_t

cenum ofp_table_feature_prop_type {
  OFPTFPT_INSTRUCTIONS       = 0;
  OFPTFPT_INSTRUCTIONS_MISS  = 1;
  OFPTFPT_NEXT_TABLES        = 2;
  OFPTFPT_NEXT_TABLES_MISS   = 3;
  OFPTFPT_WRITE_ACTIONS      = 4;
  OFPTFPT_WRITE_ACTIONS_MISS  = 5;
  OFPTFPT_APPLY_ACTIONS       = 6;
  OFPTFPT_APPLY_ACTIONS_MISS  = 7;
  OFPTFPT_MATCH               = 8;
  OFPTFPT_WILDCARDS           = 10;
  OFPTFPT_WRITE_SETFIELD      = 12;
  OFPTFPT_WRITE_SETFIELD_MISS = 13;
  OFPTFPT_APPLY_SETFIELD      = 14;
  OFPTFPT_APPLY_SETFIELD_MISS = 15;
  OFPTFPT_EXPERIMENTER        = 0xFFFE;
  OFPTFPT_EXPERIMENTER_MISS   = 0xFFFF
} as uint16_t

cstruct ofp_table_feature_prop_header {
  uint16_t typ;
  uint16_t length
} as big_endian

(* MISSING: ofp_ queues *)

cenum ofp_flow_mod_command {
  OFPFC_ADD            = 0; (* New flow. *)
  OFPFC_MODIFY         = 1; (* Modify all matching flows. *)
  OFPFC_MODIFY_STRICT  = 2; (* Modify entry strictly matching wildcards and
                              priority. *)
  OFPFC_DELETE         = 3; (* Delete all matching flows. *)
  OFPFC_DELETE_STRICT  = 4  (* Delete entry strictly matching wildcards and
                              priority. *)
} as uint8_t

cstruct ofp_flow_mod {
  uint64_t cookie;             (* Opaque controller-issued identifier. *)
  uint64_t cookie_mask;        (* Mask used to restrict the cookie bits
                                  that must match when the command is
                                  OFPFC_MODIFY* or OFPFC_DELETE*. A value
                                  of 0 indicates no restriction. *)

  (* Flow actions. *)
  uint8_t table_id;             (* ID of the table to put the flow in.
                                   For OFPFC_DELETE_* commands, OFPTT_ALL
                                   can also be used to delete matching
                                   flows from all tables. *)
  uint8_t command;              (* One of OFPFC_*. *)
  uint16_t idle_timeout;        (* Idle time before discarding (seconds). *)
  uint16_t hard_timeout;        (* Max time before discarding (seconds). *)
  uint16_t priority;            (* Priority level of flow entry. *)
  uint32_t buffer_id;           (* Buffered packet to apply to, or
                                   OFP_NO_BUFFER.
                                   Not meaningful for OFPFC_DELETE*. *)
  uint32_t out_port;            (* For OFPFC_DELETE* commands, require
                                   matching entries to include this as an
                                   output port.  A value of OFPP_ANY
                                   indicates no restriction. *)
  uint32_t out_group;           (* For OFPFC_DELETE* commands, require
                                   matching entries to include this as an
                                   output group.  A value of OFPG_ANY
                                   indicates no restriction. *)
  uint16_t flags;               (* One of OFPFF_*. *)
  uint8_t pad0;
  uint8_t pad1
} as big_endian

(* OKAY *)
cenum ofp_action_type {
  OFPAT_OUTPUT       = 0;  (* Output to switch port. *)
  OFPAT_COPY_TTL_OUT = 11; (* Copy TTL "outwards" -- from next-to-outermost
                              to outermost *)
  OFPAT_COPY_TTL_IN  = 12; (* Copy TTL "inwards" -- from outermost to
                             next-to-outermost *)
  OFPAT_SET_MPLS_TTL = 15; (* MPLS TTL *)
  OFPAT_DEC_MPLS_TTL = 16; (* Decrement MPLS TTL *)

  OFPAT_PUSH_VLAN    = 17; (* Push a new VLAN tag *)
  OFPAT_POP_VLAN     = 18; (* Pop the outer VLAN tag *)
  OFPAT_PUSH_MPLS    = 19; (* Push a new MPLS tag *)
  OFPAT_POP_MPLS     = 20; (* Pop the outer MPLS tag *)
  OFPAT_SET_QUEUE    = 21; (* Set queue id when outputting to a port *)
  OFPAT_GROUP        = 22; (* Apply group. *)
  OFPAT_SET_NW_TTL   = 23; (* IP TTL. *)
  OFPAT_DEC_NW_TTL   = 24; (* Decrement IP TTL. *)
  OFPAT_SET_FIELD    = 25; (* Set a header field using OXM TLV format. *)
  OFPAT_PUSH_PBB     = 26; (* Push a new PBB service tag (I-TAG) *)
  OFPAT_POP_PBB      = 27; (* Pop the outer PBB service tag (I-TAG) *)
  OFPAT_EXPERIMENTER = 0xffff
} as uint16_t

(* Action structure for OFPAT_OUTPUT, which sends packets out 'port'.
 * When the 'port' is the OFPP_CONTROLLER, 'max_len' indicates the max
 * number of bytes to send.  A 'max_len' of zero means no bytes of the
 * packet should be sent. A 'max_len' of OFPCML_NO_BUFFER means that
 * the packet is not buffered and the complete packet is to be sent to
 * the controller. *)
cstruct ofp_action_output {
    uint16_t typ;                   (* OFPAT_OUTPUT. *)
    uint16_t len;                   (* Length is 16. *)
    uint32_t port;                  (* Output port. *)
    uint16_t max_len;               (* Max length to send to controller. *)
    uint8_t pad0;                   (* Pad to 64 bits. *)
    uint8_t pad1;                   (* Pad to 64 bits. *)
    uint8_t pad2;                   (* Pad to 64 bits. *)
    uint8_t pad3;                   (* Pad to 64 bits. *)
    uint8_t pad4;                   (* Pad to 64 bits. *)
    uint8_t pad5                    (* Pad to 64 bits. *)
} as big_endian

(* Action structure for OFPAT_GROUP. *)
cstruct ofp_action_group {
  uint16_t typ;                   (* OFPAT_GROUP. *)
  uint16_t len;                   (* Length is 8. *)
  uint32_t group_id               (* Group identifier. *)
} as big_endian

(* Generic action header. Used for POP_VLAN *)
cstruct ofp_action_header {
  uint16_t typ;                   (* POP_VLAN. *)
  uint16_t len;                   (* Length is 8. *)
  uint8_t pad;
  uint8_t pad1;
  uint8_t pad2;
  uint8_t pad3
} as big_endian

(* Action structure for POP_MPLS *)
cstruct ofp_action_pop_mpls {
  uint16_t typ;                   (* POP_VLAN. *)
  uint16_t len;                   (* Length is 8. *)
  uint16_t ethertype;
  uint8_t pad0;                   (* Pad to 64 bits. *)
  uint8_t pad1                    (* Pad to 64 bits. *)
} as big_endian

(* Action structure for SET_NW_TTL *)
cstruct ofp_action_nw_ttl {
  uint16_t typ;                   (* SET_NW_TTL. *)
  uint16_t len;                   (* Length is 8. *)
  uint8_t nw_ttl;
  uint8_t pad;
  uint8_t pad1;
  uint8_t pad2
} as big_endian

(* Action structure for SET_MPLS_TTL *)
cstruct ofp_action_mpls_ttl {
  uint16_t typ;                   (* SET_MPLS_TTL. *)
  uint16_t len;                   (* Length is 8. *)
  uint8_t mpls_ttl;
  uint8_t pad[3];
} as big_endian

(* Action structure for *_PUSH *)
cstruct ofp_action_push {
  uint16_t typ;                   (* OFPAT_PUSH_VLAN/MPLS/PBB *)
  uint16_t len;                   (* Length is 8. *)
  uint16_t ethertype;             (* Pad to 64 bits. *)
  uint8_t pad0;                   (* Pad to 64 bits. *)
  uint8_t pad1                   (* Pad to 64 bits. *)
} as big_endian

(* Action structure for OFPAT_SET_FIELD. *)
cstruct ofp_action_set_field {
    uint16_t typ;                  (* OFPAT_SET_FIELD. *)
    uint16_t len                   (* Length is padded to 64 bits. *)
    (* Followed by:
     *   - Exactly oxm_len bytes containing a single OXM TLV, then
     *   - Exactly ((oxm_len + 4) + 7)/8*8 - (oxm_len + 4) (between 0 and 7)
     *     bytes of all-zero bytes
     *)
} as big_endian

(* Action structure for SET_QUEUE *)
cstruct ofp_action_set_queue {
   uint16_t typ;                   (* OFPAT_SET_QUEUE*)
   uint16_t len;                   (* Length is 8. *)
   uint32_t queue_id
} as big_endian

cstruct ofp_action_experimenter { 
   uint16_t typ;
   uint16_t len;
   uint32_t experimenter
} as big_endian

(* Instruction header that is common to all instructions.  The length includes
 * the header and any padding used to make the instruction 64-bit aligned.
 * NB: The length of an instruction *must* always be a multiple of eight. *)
cstruct ofp_instruction {
    uint16_t typ;                 (* Instruction type *)
    uint16_t len                  (* Length of this struct in bytes. *)
} as big_endian

cenum ofp_instruction_type {
    OFPIT_GOTO_TABLE        = 1;
    OFPIT_WRITE_METADATA    = 2;
    OFPIT_WRITE_ACTIONS     = 3;
    OFPIT_APPLY_ACTIONS     = 4;
    OFPIT_CLEAR_ACTIONS     = 5;
    OFPIT_METER             = 6;
    OFPIT_EXPERIMENTER      = 0xFFFF;
} as uint16_t

(* Instruction structure for OFPIT_GOTO_TABLE *)
cstruct ofp_instruction_goto_table {
    uint16_t typ;                 (* OFPIT_GOTO_TABLE *)
    uint16_t len;                 (* Length of this struct in bytes. *)
    uint8_t table_id;             (* Set next table in the lookup pipeline *)
    uint8_t pad0;                 (* Pad to 64 bits. *)
    uint8_t pad1;
    uint8_t pad2
} as big_endian

(* Instruction structure for OFPIT_WRITE_METADATA *)
cstruct ofp_instruction_write_metadata {
    uint16_t typ;                 (* OFPIT_WRITE_METADATA *)
    uint16_t len;                 (* Length of this struct in bytes. *)
    uint8_t pad0;                 (* Align to 64-bits *)
    uint8_t pad1;
    uint8_t pad2;
    uint8_t pad3;
    uint64_t metadata;            (* Metadata value to write *)
    uint64_t metadata_mask        (* Metadata write bitmask *)
} as big_endian

(* Instruction structure for OFPIT_WRITE/APPLY/CLEAR_ACTIONS *)
cstruct ofp_instruction_actions {
    uint16_t typ;               (* One of OFPIT_*_ACTIONS *)
    uint16_t len;               (* Length of this struct in bytes. *)
    uint8_t pad0;               (* Align to 64-bits *)
    uint8_t pad1;
    uint8_t pad2;
    uint8_t pad3
} as big_endian

(* Instruction structure for OFPIT_METER *)
cstruct ofp_instruction_meter {
    uint16_t typ;                 (* OFPIT_METER *)
    uint16_t len;                 (* Length is 8. *)
    uint32_t meter_id             (* Meter instance. *)
} as big_endian

(* Instruction structure for experimental instructions *)
cstruct ofp_instruction_experimenter {
    uint16_t typ;               (* OFPIT_EXPERIMENTER *)
    uint16_t len;               (* Length of this struct in bytes *)
    uint32_t experimenter       (* Experimenter ID which takes the same form
                                   as in struct ofp_experimenter_header. *)
    (* Experimenter-defined arbitrary additional data. *)
} as big_endian


cenum ofp_group_type {
  OFPGC_ALL = 0; (* All (multicast/broadcast) group. *)
  OFPGC_SELECT = 1; (* Select group. *)
  OFPGC_INDIRECT = 2; (* Indirect group. *)
  OFPGC_FF = 3 (* Fast failover group. *)
} as uint16_t

(* Group setup and teardown (controller -> datapath). *)
cstruct ofp_group_mod {
  uint16_t command;             (* One of OFPGC_*. *)
  uint8_t typ;                 (* One of OFPGT_*. *)
  uint8_t pad;                  (* Pad to 64 bits. *)
  uint32_t group_id            (* Group identifier. *)
} as big_endian

(* Bucket for use in groups. *)
cstruct ofp_bucket {
  uint16_t len;                   (* Length the bucket in bytes, including
                                     this header and any padding to make it
                                     64-bit aligned. *)
  uint16_t weight;                (* Relative weight of bucket.  Only
                                     defined for select groups. *)
  uint32_t watch_port;            (* Port whose state affects whether this
                                     bucket is live.  Only required for fast
                                     failover groups. *)
  uint32_t watch_group;           (* Group whose state affects whether this
                                     bucket is live.  Only required for fast
                                     failover groups. *)
  uint8_t pad0;
  uint8_t pad1;
  uint8_t pad2;
  uint8_t pad3
} as big_endian

cstruct ofp_oxm {
  uint16_t oxm_class;
  uint8_t oxm_field_and_hashmask;
  uint8_t oxm_length
} as big_endian


cstruct ofp_multipart_request {
	uint16_t typ;   (* One of the OFPMP_* constants. *)
	uint16_t flags;  (* OFPMP_REQ_* flags (none yet defined). *)
	uint8_t pad[4];
	uint8_t body[0] (* Body of the request. *)
} as big_endian

cenum ofp_multipart_request_flags {
    OFPMPF_REQ_MORE = 1 (* More requests to follow. *)
} as uint16_t

cenum ofp_multipart_reply_flags {
    OFPMPF_REPLY_MORE  = 1  (* More replies to follow. *)
} as uint16_t

cstruct ofp_multipart_reply {
	uint16_t typ;   (* One of the OFPMP_* constants. *)
	uint16_t flags;  (* OFPMP_REPLY_* flags. *)
	uint8_t pad[4];
	uint8_t body[0] (* Body of the reply. *)
} as big_endian

cenum ofp_multipart_types {
    (* Description of this OpenFlow switch.
    * The request body is empty.
    * The reply body is struct ofp_desc. *)
    OFPMP_DESC = 0;
    (* Individual flow statistics.
    * The request body is struct ofp_flow_multipart_request.
    * The reply body is an array of struct ofp_flow_stats. *)
    OFPMP_FLOW = 1;
    (* Aggregate flow statistics.
    * The request body is struct ofp_aggregate_stats_request.
    * The reply body is struct ofp_aggregate_stats_reply. *)
    OFPMP_AGGREGATE = 2;
    (* Flow table statistics.
    * The request body is empty.
    * The reply body is an array of struct ofp_table_stats. *)
    OFPMP_TABLE = 3;
    (* Port statistics.
    * The request body is struct ofp_port_stats_request.
    * The reply body is an array of struct ofp_port_stats. *)
    OFPMP_PORT_STATS = 4;
    (* Queue statistics for a port
    * The request body is struct ofp_queue_stats_request.
    * The reply body is an array of struct ofp_queue_stats *)
    OFPMP_QUEUE = 5;
    (* Group counter statistics.
    * The request body is struct ofp_group_stats_request.
    * The reply is an array of struct ofp_group_stats. *)
    OFPMP_GROUP = 6;
    (* Group description statistics.
    * The request body is empty.
    * The reply body is an array of struct ofp_group_desc_stats. *)
    OFPMP_GROUP_DESC = 7;
    (* Group features.
    * The request body is empty.
    * The reply body is struct ofp_group_features_stats. *)
    OFPMP_GROUP_FEATURES = 8;
    (* Meter statistics.
     * The request body is struct ofp_meter_multipart_requests.
     * The reply body is an array of struct ofp_meter_stats. *)
    OFPMP_METER = 9;
    (* Meter configuration.
    * The request body is struct ofp_meter_multipart_requests.
    * The reply body is an array of struct ofp_meter_config. *)
    OFPMP_METER_CONFIG = 10;
    (* Meter features.
    * The request body is empty.
    * The reply body is struct ofp_meter_features. *)
    OFPMP_METER_FEATURES = 11;
    (* Table features.
    * The request body is either empty or contains an array of
    * struct ofp_table_features containing the controller’s
    * desired view of the switch. If the switch is unable to
    * set the specified view an error is returned.
    * The reply body is an array of struct ofp_table_features. *)
    OFPMP_TABLE_FEATURES = 12;
    (* Port description.
    * The request body is empty.
    * The reply body is an array of struct ofp_port. *)
    OFPMP_PORT_DESC = 13;
    (* Experimenter extension.
    * The request and reply bodies begin with
    * struct ofp_experimenter_stats_header.
    * The request and reply bodies are otherwise experimenter-defined. *)
    OFPMP_EXPERIMENTER = 0xffff
} as uint16_t

cstruct ofp_desc {
    uint8_t mfr_desc[256];
    uint8_t hw_desc[256];
    uint8_t sw_desc[256];
    uint8_t serial_num[32];
  } as big_endian

cstruct ofp_uint8 {
  uint8_t value
} as big_endian

cstruct ofp_uint16 {
  uint16_t value
} as big_endian

cstruct ofp_uint32 {
  uint32_t value
} as big_endian

cstruct ofp_uint48 {
  uint32_t high;
  uint16_t low
} as big_endian

cstruct ofp_uint64 {
  uint64_t value
} as big_endian

let max_uint32 = 4294967296L (* = 2^32*)

let compare_uint32 a b =
(* val compare_uint32 : uint32 -> uint32 -> bool ; return a < b, for a, b uint32  *)
    let a' = if a < 0l then  
                Int64.sub max_uint32 (Int64.of_int32 (Int32.abs a))
             else Int64.of_int32 a in
    let b' = if b < 0l then
                Int64.sub max_uint32 (Int64.of_int32 (Int32.abs b))
             else Int64.of_int32 b in
    a' <= b'

let set_ofp_uint48_value (buf : Cstruct.t) (value : uint48) =
  let high = Int32.of_int ((Int64.to_int value) lsr 16) in
    let low = ((Int64.to_int value) land 0xffff) in
      set_ofp_uint48_high buf high;
      set_ofp_uint48_low buf low

let get_ofp_uint48_value (buf : Cstruct.t) : uint48 =
  let highBits = get_ofp_uint48_high buf in
  let high = Int64.shift_left (
    if highBits < 0l then
      Int64.sub 4294967296L (Int64.of_int32 (Int32.abs highBits))
    else
      Int64.of_int32 highBits) 16 in
  let low = Int64.of_int (get_ofp_uint48_low buf) in
  Int64.logor low high

let rec marshal_fields (buf: Cstruct.t) (fields : 'a list) (marshal_func : Cstruct.t -> 'a -> int ): int =
  if (fields = []) then 0
  else let size = marshal_func buf (List.hd fields) in
    size + (marshal_fields (Cstruct.shift buf size) (List.tl fields) marshal_func)

let pad_to_64bits (n : int) : int =
  if n land 0x7 <> 0 then
    n + (8 - (n land 0x7))
  else
    n

let rec pad_with_zeros (buf : Cstruct.t) (pad : int) : int =
  if pad = 0 then 0
  else begin set_ofp_uint8_value buf 0;
    1 + pad_with_zeros (Cstruct.shift buf 1) (pad - 1) end

let test_bit16 (n:int) (x:int) : bool =
  (x lsr n) land 1 = 1

module Oxm = struct

  let field_length (oxm : oxm) : int = match oxm with
    | OxmInPort _ -> 4
    | OxmInPhyPort _ -> 4
    | OxmEthType  _ -> 2
    | OxmEthDst ethaddr ->
      (match ethaddr.m_mask with
        | None -> 6
        | Some _ -> 12)
    | OxmEthSrc ethaddr ->
      (match ethaddr.m_mask with
        | None -> 6
        | Some _ -> 12)
    | OxmVlanVId vid ->
      (match vid.m_mask with
        | None -> 2
        | Some _ -> 4)
    | OxmVlanPcp _ -> 1
    | OxmIP4Src ipaddr -> 
      (match ipaddr.m_mask with
        | None -> 4
        | Some _ -> 8)
    | OxmIP4Dst ipaddr ->       
      (match ipaddr.m_mask with
        | None -> 4
        | Some _ -> 8)
    | OxmTCPSrc tcpPort ->
      (match tcpPort.m_mask with
        | None -> 2
        | Some _ -> 4)
    | OxmTCPDst tcpPort ->
      (match tcpPort.m_mask with
        | None -> 2
        | Some _ -> 4)
    | OxmARPOp _ -> 2
    | OxmARPSpa t->
      (match t.m_mask with
        | None -> 4
        | Some _ -> 8)
    | OxmARPTpa t->
      (match t.m_mask with
        | None -> 4
        | Some _ -> 8)
    | OxmARPSha t->
      (match t.m_mask with
        | None -> 6
        | Some _ -> 12)
    | OxmARPTha t->
      (match t.m_mask with
        | None -> 6
        | Some _ -> 12)
    | OxmMPLSLabel _ -> 4
    | OxmMPLSTc _ -> 1
    | OxmMetadata t -> 
      (match t.m_mask with
        | None -> 8
        | Some _ -> 16)
    | OxmIPProto _ -> 1
    | OxmIPDscp _ -> 1
    | OxmIPEcn _ -> 1
    | OxmICMPType _ -> 1
    | OxmICMPCode _ -> 1
    | OxmTunnelId t ->
      (match t.m_mask with
        | None -> 8
        | Some _ -> 16)

  let field_name (oxm : oxm) : string = match oxm with
    | OxmInPort _ -> "InPort"
    | OxmInPhyPort _ -> "InPhyPort"
    | OxmEthType  _ -> "EthType"
    | OxmEthDst ethaddr ->
      (match ethaddr.m_mask with
        | None -> "EthDst"
        | Some _ -> "EthDst/mask")
    | OxmEthSrc ethaddr ->
      (match ethaddr.m_mask with
        | None -> "EthSrc"
        | Some _ -> "EthSrc/mask")
    | OxmVlanVId vid ->
      (match vid.m_mask with
        | None -> "VlanVId"
        | Some _ -> "VlanVId/mask")
    | OxmVlanPcp _ -> "VlanPcp"
    | OxmIP4Src ipaddr -> 
      (match ipaddr.m_mask with
        | None -> "IPSrc"
        | Some _ -> "IPSrc/mask")
    | OxmIP4Dst ipaddr ->       
      (match ipaddr.m_mask with
        | None -> "IPDst"
        | Some _ -> "IPDst/mask")
    | OxmTCPSrc tcpPort ->
      (match tcpPort.m_mask with
        | None -> "TCPSrc"
        | Some _ -> "TCPSrc/mask")
    | OxmTCPDst tcpPort ->
      (match tcpPort.m_mask with
        | None -> "TCPDst"
        | Some _ -> "TCPDst/mask")
    | OxmARPOp _ -> "ARPOp"
    | OxmARPSpa t->
      (match t.m_mask with
        | None -> "ARPSpa"
        | Some _ -> "ARPSpa/mask")
    | OxmARPTpa t->
      (match t.m_mask with
        | None -> "ARPTpa"
        | Some _ -> "ARPTpa/mask")
    | OxmARPSha t->
      (match t.m_mask with
        | None -> "ARPSha"
        | Some _ -> "ARPSha/mask")
    | OxmARPTha t->
      (match t.m_mask with
        | None -> "ARPTha"
        | Some _ -> "ARPTha/mask")
    | OxmMPLSLabel _ -> "MPLSLabel"
    | OxmMPLSTc _ -> "MplsTc"
    | OxmMetadata t -> 
      (match t.m_mask with
        | None -> "Metadata"
        | Some _ -> "Metadata/mask")
    | OxmIPProto _ -> "IPProto"
    | OxmIPDscp _ -> "IPDscp"
    | OxmIPEcn _ -> "IPEcn"
    | OxmICMPType _ -> "ICMP Type"
    | OxmICMPCode _ -> "ICMP Code"
    | OxmTunnelId t ->
      (match t.m_mask with
        | None -> "Tunnel ID"
        | Some _ -> "Tunnel ID/mask")

  let sizeof (oxm : oxm) : int =
    sizeof_ofp_oxm + field_length oxm

  let sizeof_header (oxml : oxm list) : int =
    (List.length oxml) * 4

  let to_string oxm =
    match oxm with
    | OxmInPort p -> Format.sprintf "InPort : %lu " p
    | OxmInPhyPort p -> Format.sprintf "InPhyPort : %lu " p
    | OxmEthType  e -> Format.sprintf "EthType : %X " e
    | OxmEthDst ethaddr ->
      (match ethaddr.m_mask with
        | None -> Format.sprintf "EthDst : %LX" ethaddr.m_value
        | Some m -> Format.sprintf "EthDst : %LX/%LX" ethaddr.m_value m)
    | OxmEthSrc ethaddr ->
      (match ethaddr.m_mask with
        | None -> Format.sprintf "EthSrc : %LX" ethaddr.m_value
        | Some m -> Format.sprintf "EthSrc : %LX/%LX" ethaddr.m_value m)
    | OxmVlanVId vid ->
      (match vid.m_mask with
        | None -> Format.sprintf "VlanVId : %u" vid.m_value
        | Some m -> Format.sprintf "VlanVId : %u/%u" vid.m_value m)
    | OxmVlanPcp vid -> Format.sprintf "VlanPcp : %u" vid
    | OxmIP4Src ipaddr ->
      (match ipaddr.m_mask with
        | None -> Format.sprintf "IPSrc : %s" (string_of_ip ipaddr.m_value)
        | Some m -> Format.sprintf "IPSrc : %s/%s" (string_of_ip ipaddr.m_value)
                                                (string_of_ip m))
    | OxmIP4Dst ipaddr -> 
      (match ipaddr.m_mask with
        | None -> Format.sprintf "IPDst : %s" (string_of_ip ipaddr.m_value)
        | Some m -> Format.sprintf "IPDst : %s/%s" (string_of_ip ipaddr.m_value)
                                                   (string_of_ip m))
    | OxmTCPSrc v -> (match v.m_mask with
        | None -> Format.sprintf "TCPSrc : %u" v.m_value
        | Some m -> Format.sprintf "TCPSrc : %u/%u" v.m_value m)
    | OxmTCPDst v -> (match v.m_mask with
        | None -> Format.sprintf "TCPDst : %u" v.m_value
        | Some m -> Format.sprintf "TCPDst : %u/%u" v.m_value m)
    | OxmMPLSLabel v -> Format.sprintf "MPLSLabel : %lu" v
    | OxmMPLSTc v -> Format.sprintf "MplsTc : %u" v 
    | OxmMetadata v ->
      (match v.m_mask with
        | None -> Format.sprintf "Metadata : %Lu" v.m_value
        | Some m -> Format.sprintf "Metadata : %Lu/%Lu" v.m_value m)
    | OxmIPProto v -> Format.sprintf "IPProto : %u" v
    | OxmIPDscp v -> Format.sprintf "IPDscp : %u" v
    | OxmIPEcn v -> Format.sprintf "IPEcn : %u" v
    | OxmARPOp v -> Format.sprintf "ARPOp : %u" v
    | OxmARPSpa v ->
      (match v.m_mask with
        | None -> Format.sprintf "ARPSpa : %lu" v.m_value
        | Some m -> Format.sprintf "ARPSpa : %lu/%lu" v.m_value m)
    | OxmARPTpa v ->
      (match v.m_mask with
        | None -> Format.sprintf "ARPTpa : %lu" v.m_value
        | Some m -> Format.sprintf "ARPTpa : %lu/%lu" v.m_value m)
    | OxmARPSha v ->
      (match v.m_mask with
        | None -> Format.sprintf "ARPSha : %Lu" v.m_value
        | Some m -> Format.sprintf "ARPSha : %Lu/%Lu" v.m_value m)
    | OxmARPTha v ->
      (match v.m_mask with
        | None -> Format.sprintf "ARPTha : %Lu" v.m_value
        | Some m -> Format.sprintf "ARPTha : %Lu/%Lu" v.m_value m)
    | OxmICMPType v -> Format.sprintf "ICMP Type : %u" v
    | OxmICMPCode v -> Format.sprintf "ICMP Code : %u" v
    | OxmTunnelId v -> 
      (match v.m_mask with
        | None -> Format.sprintf "Tunnel ID : %Lu" v.m_value
        | Some m -> Format.sprintf "Tunnel ID : %Lu/%Lu" v.m_value m)

  let set_ofp_oxm (buf : Cstruct.t) (c : ofp_oxm_class) (f : oxm_ofb_match_fields) (hm : int) (l : int) = 
    let value = (0x7f land (oxm_ofb_match_fields_to_int f)) lsl 1 in
      let value = value lor (0x1 land hm) in
        set_ofp_oxm_oxm_class buf (ofp_oxm_class_to_int c);
        set_ofp_oxm_oxm_field_and_hashmask buf value;
        set_ofp_oxm_oxm_length buf l


  let marshal (buf : Cstruct.t) (oxm : oxm) : int = 
    let l = field_length oxm in
      let ofc = OFPXMC_OPENFLOW_BASIC in
        let buf2 = Cstruct.shift buf sizeof_ofp_oxm in
          match oxm with
            | OxmInPort pid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IN_PORT 0 l;
              set_ofp_uint32_value buf2 pid;
              sizeof_ofp_oxm + l
            | OxmInPhyPort pid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IN_PHY_PORT 0 l;
              set_ofp_uint32_value buf2 pid;
              sizeof_ofp_oxm + l
            | OxmEthType ethtype ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ETH_TYPE 0 l;
              set_ofp_uint16_value buf2 ethtype;
              sizeof_ofp_oxm + l
            | OxmEthDst ethaddr ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ETH_DST (match ethaddr.m_mask with None -> 0 | _ -> 1) l;
              set_ofp_uint48_value buf2 ethaddr.m_value;
              begin match ethaddr.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint48_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmEthSrc ethaddr ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ETH_SRC (match ethaddr.m_mask with None -> 0 | _ -> 1) l;
              set_ofp_uint48_value buf2 ethaddr.m_value;
              begin match ethaddr.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint48_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmIP4Src ipaddr ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IPV4_SRC (match ipaddr.m_mask with None -> 0 | _ -> 1) l;
              set_ofp_uint32_value buf2 ipaddr.m_value;
              begin match ipaddr.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint32_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmIP4Dst ipaddr ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IPV4_DST (match ipaddr.m_mask with None -> 0 | _ -> 1) l;
              set_ofp_uint32_value buf2 ipaddr.m_value;
              begin match ipaddr.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint32_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmVlanVId vid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_VLAN_VID (match vid.m_mask with None -> 0 | _ -> 1) l;
              set_ofp_uint16_value buf2 vid.m_value;
              begin match vid.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint16_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmVlanPcp vid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_VLAN_PCP 0 l;
              set_ofp_uint8_value buf2 vid;
              sizeof_ofp_oxm + l
            | OxmMPLSLabel vid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_MPLS_LABEL 0 l;
              set_ofp_uint32_value buf2 vid;
              sizeof_ofp_oxm + l
            | OxmMPLSTc vid ->
              set_ofp_oxm buf ofc OFPXMT_OFB_MPLS_TC 0 l;
              set_ofp_uint8_value buf2 vid;
              sizeof_ofp_oxm + l
            | OxmMetadata meta ->
              set_ofp_oxm buf ofc OFPXMT_OFB_METADATA  (match meta.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint64_value buf2 meta.m_value;
              begin match meta.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint64_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmIPProto ipproto ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IP_PROTO 0 l;
              set_ofp_uint8_value buf2 ipproto;
              sizeof_ofp_oxm + l
            | OxmIPDscp ipdscp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IP_DSCP 0 l;
              set_ofp_uint8_value buf2 ipdscp;
              sizeof_ofp_oxm + l
            | OxmIPEcn ipecn ->
              set_ofp_oxm buf ofc OFPXMT_OFB_IP_ECN 0 l;
              set_ofp_uint8_value buf2 ipecn;
              sizeof_ofp_oxm + l
            | OxmTCPSrc port ->
              set_ofp_oxm buf ofc OFPXMT_OFB_TCP_SRC  (match port.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint16_value buf2 port.m_value;
              begin match port.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint16_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmTCPDst port ->
              set_ofp_oxm buf ofc OFPXMT_OFB_TCP_DST  (match port.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint16_value buf2 port.m_value;
              begin match port.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint16_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmARPOp arp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ARP_OP 0 l;
              set_ofp_uint16_value buf2 arp;
              sizeof_ofp_oxm + l
            | OxmARPSpa arp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ARP_SPA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint32_value buf2 arp.m_value;
              begin match arp.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint32_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmARPTpa arp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ARP_TPA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint32_value buf2 arp.m_value;
              begin match arp.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint32_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmARPSha arp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ARP_SHA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint48_value buf2 arp.m_value;
              begin match arp.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint48_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmARPTha arp ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ARP_THA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint48_value buf2 arp.m_value;
              begin match arp.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint48_value buf3 mask;
                    sizeof_ofp_oxm + l
              end
            | OxmICMPType t ->
              set_ofp_oxm buf ofc OFPXMT_OFB_ICMPV4_TYPE 0 l;
              set_ofp_uint8_value buf2 t;
              sizeof_ofp_oxm + l
            | OxmICMPCode c->
              set_ofp_oxm buf ofc OFPXMT_OFB_ICMPV4_CODE 0 l;
              set_ofp_uint8_value buf2 c;
              sizeof_ofp_oxm + l
            | OxmTunnelId tun ->
              set_ofp_oxm buf ofc OFPXMT_OFB_TUNNEL_ID  (match tun.m_mask with None -> 0 | _ -> 1)  l;
              set_ofp_uint64_value buf2 tun.m_value;
              begin match tun.m_mask with
                | None ->
                  sizeof_ofp_oxm + l
                | Some mask ->
                  let buf3 = Cstruct.shift buf2 (l/2) in
                    set_ofp_uint64_value buf3 mask;
                    sizeof_ofp_oxm + l
              end

  let marshal_header (buf : Cstruct.t) (oxm : oxm) : int = 
  (* Same as marshal, but without the payload *)
    let l = field_length oxm in
      let ofc = OFPXMC_OPENFLOW_BASIC in
        match oxm with
          | OxmInPort _ ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IN_PORT 0 l;
            sizeof_ofp_oxm
          | OxmInPhyPort _ ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IN_PHY_PORT 0 l;
            sizeof_ofp_oxm
          | OxmEthType _ ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ETH_TYPE 0 l;
            sizeof_ofp_oxm
          | OxmEthDst ethaddr ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ETH_DST (match ethaddr.m_mask with None -> 0 | _ -> 1) l;
            sizeof_ofp_oxm
          | OxmEthSrc ethaddr ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ETH_SRC (match ethaddr.m_mask with None -> 0 | _ -> 1) l;
            sizeof_ofp_oxm
          | OxmIP4Src ipaddr ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IPV4_SRC (match ipaddr.m_mask with None -> 0 | _ -> 1) l;
            sizeof_ofp_oxm
          | OxmIP4Dst ipaddr ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IPV4_DST (match ipaddr.m_mask with None -> 0 | _ -> 1) l;
            sizeof_ofp_oxm
          | OxmVlanVId vid ->
            set_ofp_oxm buf ofc OFPXMT_OFB_VLAN_VID (match vid.m_mask with None -> 0 | _ -> 1) l;
            sizeof_ofp_oxm
          | OxmVlanPcp vid ->
            set_ofp_oxm buf ofc OFPXMT_OFB_VLAN_PCP 0 l;
            sizeof_ofp_oxm
          | OxmMPLSLabel vid ->
            set_ofp_oxm buf ofc OFPXMT_OFB_MPLS_LABEL 0 l;
            sizeof_ofp_oxm
          | OxmMPLSTc vid ->
            set_ofp_oxm buf ofc OFPXMT_OFB_MPLS_TC 0 l;
            sizeof_ofp_oxm
          | OxmMetadata meta ->
            set_ofp_oxm buf ofc OFPXMT_OFB_METADATA  (match meta.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmIPProto ipproto ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IP_PROTO 0 l;
            sizeof_ofp_oxm
          | OxmIPDscp ipdscp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IP_DSCP 0 l;
            sizeof_ofp_oxm
          | OxmIPEcn ipecn ->
            set_ofp_oxm buf ofc OFPXMT_OFB_IP_ECN 0 l;
            sizeof_ofp_oxm
          | OxmTCPSrc port ->
            set_ofp_oxm buf ofc OFPXMT_OFB_TCP_SRC  (match port.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmTCPDst port ->
            set_ofp_oxm buf ofc OFPXMT_OFB_TCP_DST  (match port.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmARPOp arp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ARP_OP 0 l;
            sizeof_ofp_oxm
          | OxmARPSpa arp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ARP_SPA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmARPTpa arp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ARP_TPA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmARPSha arp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ARP_SHA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmARPTha arp ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ARP_THA  (match arp.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm
          | OxmICMPType t ->
            set_ofp_oxm buf ofc OFPXMT_OFB_ICMPV4_TYPE 0 l;
            sizeof_ofp_oxm
          | OxmICMPCode c->
            set_ofp_oxm buf ofc OFPXMT_OFB_ICMPV4_CODE 0 l;
            sizeof_ofp_oxm
          | OxmTunnelId tun ->
            set_ofp_oxm buf ofc OFPXMT_OFB_TUNNEL_ID  (match tun.m_mask with None -> 0 | _ -> 1)  l;
            sizeof_ofp_oxm

  let parse (bits : Cstruct.t) : oxm * Cstruct.t =
    (* printf "class= %d\n" (get_ofp_oxm_oxm_class bits); *)
    (* let c = match int_to_ofp_oxm_class (get_ofp_oxm_oxm_class bits) with *)
    (*   | Some n -> n *)
    (*   | None ->  *)
    (*     raise (Unparsable (sprintf "malformed class in oxm")) in *)
    (* TODO: assert c is OFPXMC_OPENFLOW_BASIC *)
    let value = get_ofp_oxm_oxm_field_and_hashmask bits in
    let f = match int_to_oxm_ofb_match_fields (value lsr 1) with
      | Some n -> n
      | None -> 
        raise (Unparsable (sprintf "malformed field in oxm %d" (value lsr 1))) in
    let hm = value land 0x1 in
    let oxm_length = get_ofp_oxm_oxm_length bits in
    let bits = Cstruct.shift bits sizeof_ofp_oxm in
    let bits2 = Cstruct.shift bits oxm_length in
    match f with
      | OFPXMT_OFB_IN_PORT ->
        let pid = get_ofp_uint32_value bits in
        (OxmInPort pid, bits2)
      | OFPXMT_OFB_IN_PHY_PORT ->
        let pid = get_ofp_uint32_value bits in
        (OxmInPhyPort pid, bits2)
      | OFPXMT_OFB_METADATA ->
        let value = get_ofp_uint64_value bits in
        if hm = 1 then
          let bits = Cstruct.shift bits 8 in
          let mask = get_ofp_uint64_value bits in
          (OxmMetadata {m_value = value; m_mask = (Some mask)}, bits2)
        else
          (OxmMetadata {m_value = value; m_mask = None}, bits2)
      | OFPXMT_OFB_TUNNEL_ID ->
        let value = get_ofp_uint64_value bits in
        if hm = 1 then
          let bits = Cstruct.shift bits 8 in
          let mask = get_ofp_uint64_value bits in
          (OxmTunnelId {m_value = value; m_mask = (Some mask)}, bits2)
        else
          (OxmTunnelId {m_value = value; m_mask = None}, bits2)
      (* Ethernet destination address. *)
      | OFPXMT_OFB_ETH_DST ->
	let value = get_ofp_uint48_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 6 in
	  let mask = get_ofp_uint48_value bits in
	  (OxmEthDst {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmEthDst {m_value = value; m_mask = None}, bits2)
      (* Ethernet source address. *)
      | OFPXMT_OFB_ETH_SRC ->
	let value = get_ofp_uint48_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 6 in
	  let mask = get_ofp_uint48_value bits in
	  (OxmEthSrc {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmEthSrc {m_value = value; m_mask = None}, bits2)
      (* Ethernet frame type. *)
      | OFPXMT_OFB_ETH_TYPE ->
	let value = get_ofp_uint16_value bits in
	  (OxmEthType value, bits2)
      (* IP protocol. *)
      | OFPXMT_OFB_IP_PROTO ->
	let value = get_ofp_uint8_value bits in
	  (OxmIPProto value, bits2)
      (* IP DSCP (6 bits in ToS field). *)
      | OFPXMT_OFB_IP_DSCP ->
	let value = get_ofp_uint8_value bits in
	  (OxmIPDscp (value land 63), bits2)
      (* IP ECN (2 bits in ToS field). *)
      |  OFPXMT_OFB_IP_ECN ->
	let value = get_ofp_uint8_value bits in
	  (OxmIPEcn (value land 3), bits2)
      (* IPv4 source address. *)
      | OFPXMT_OFB_IPV4_SRC ->
	let value = get_ofp_uint32_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 4 in
	  let mask = get_ofp_uint32_value bits in
	  (OxmIP4Src {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmIP4Src {m_value = value; m_mask = None}, bits2)
      (* IPv4 destination address. *)
      | OFPXMT_OFB_IPV4_DST ->
	let value = get_ofp_uint32_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 4 in
	  let mask = get_ofp_uint32_value bits in
	  (OxmIP4Dst {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmIP4Dst {m_value = value; m_mask = None}, bits2)
      (* ARP opcode. *)
      | OFPXMT_OFB_ARP_OP ->
	let value = get_ofp_uint16_value bits in
	  (OxmARPOp value, bits2)
      (* ARP source IPv4 address. *)
      | OFPXMT_OFB_ARP_SPA ->
	let value = get_ofp_uint32_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 4 in
	  let mask = get_ofp_uint32_value bits in
	  (OxmARPSpa {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmARPSpa {m_value = value; m_mask = None}, bits2)
      (* ARP target IPv4 address. *)
      | OFPXMT_OFB_ARP_TPA ->
	let value = get_ofp_uint32_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 4 in
	  let mask = get_ofp_uint32_value bits in
	  (OxmARPTpa {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmARPTpa {m_value = value; m_mask = None}, bits2)
      (* ARP source hardware address. *)
      | OFPXMT_OFB_ARP_SHA ->
	let value = get_ofp_uint48_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 6 in
	  let mask = get_ofp_uint48_value bits in
	  (OxmARPSha {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmARPSha {m_value = value; m_mask = None}, bits2)
      (* ARP target hardware address. *)
      | OFPXMT_OFB_ARP_THA ->
	let value = get_ofp_uint48_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 6 in
	  let mask = get_ofp_uint48_value bits in
	  (OxmARPTha {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmARPTha {m_value = value; m_mask = None}, bits2)
      (* ICMP Type *)
      | OFPXMT_OFB_ICMPV4_TYPE ->
	let value = get_ofp_uint8_value bits in
	  (OxmICMPType value, bits2)
      (* ICMP code. *)
      |   OFPXMT_OFB_ICMPV4_CODE ->
	let value = get_ofp_uint8_value bits in
	  (OxmICMPCode value, bits2)
      | OFPXMT_OFB_TCP_DST ->
    let value = get_ofp_uint16_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 2 in
	  let mask = get_ofp_uint16_value bits in
	  (OxmTCPDst {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmTCPDst {m_value = value; m_mask = None}, bits2)
      | OFPXMT_OFB_TCP_SRC ->
    let value = get_ofp_uint16_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 2 in
	  let mask = get_ofp_uint16_value bits in
	  (OxmTCPSrc {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmTCPSrc {m_value = value; m_mask = None}, bits2)
      | OFPXMT_OFB_MPLS_LABEL ->
    let value = get_ofp_uint32_value bits in
	  (OxmMPLSLabel value, bits2)
      | OFPXMT_OFB_VLAN_PCP ->
    let value = get_ofp_uint8_value bits in
	  (OxmVlanPcp value, bits2)
      | OFPXMT_OFB_VLAN_VID ->
    let value = get_ofp_uint16_value bits in
	if hm = 1 then
	  let bits = Cstruct.shift bits 2 in
	  let mask = get_ofp_uint16_value bits in
	  (OxmVlanVId {m_value = value; m_mask = (Some mask)}, bits2)
	else
	  (OxmVlanVId {m_value = value; m_mask = None}, bits2)
      | OFPXMT_OFB_MPLS_TC ->
    let value = get_ofp_uint8_value bits in
	  (OxmMPLSTc value, bits2)
      | _ -> raise (Unparsable (sprintf "malformed packet in oxm %d\n" (value lsr 1)))

    let parse_header (bits : Cstruct.t) : oxm * Cstruct.t =
    (* parse Oxm header function for TableFeatureProp. Similar to parse, but without
       parsing the payload *)
      let value = get_ofp_oxm_oxm_field_and_hashmask bits in
      let f = match int_to_oxm_ofb_match_fields (value lsr 1) with
        | Some n -> n
        | None -> raise (Unparsable (sprintf "malformed field in oxm %d" (value lsr 1))) in
      let hm = value land 0x1 in
      let bits2 = Cstruct.shift bits sizeof_ofp_oxm in
      match f with
        | OFPXMT_OFB_IN_PORT ->
          (OxmInPort 0l, bits2)
        | OFPXMT_OFB_IN_PHY_PORT ->
          (OxmInPhyPort 0l, bits2)
        | OFPXMT_OFB_METADATA ->
          if hm = 1 then
            (OxmMetadata {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmMetadata {m_value = 0L; m_mask = None}, bits2)
        | OFPXMT_OFB_TUNNEL_ID ->
          if hm = 1 then
            (OxmTunnelId {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmTunnelId {m_value = 0L; m_mask = None}, bits2)
        (* Ethernet destination address. *)
        | OFPXMT_OFB_ETH_DST ->
          if hm = 1 then
            (OxmEthDst {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmEthDst {m_value = 0L; m_mask = None}, bits2)
        (* Ethernet source address. *)
        | OFPXMT_OFB_ETH_SRC ->
          if hm = 1 then
            (OxmEthSrc {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmEthSrc {m_value = 0L; m_mask = None}, bits2)
         (* Ethernet frame type. *)
        | OFPXMT_OFB_ETH_TYPE ->
            (OxmEthType 0, bits2)
         (* IP protocol. *)
        | OFPXMT_OFB_IP_PROTO ->
            (OxmIPProto 0, bits2)
        (* IP DSCP (6 bits in ToS field). *)
        | OFPXMT_OFB_IP_DSCP ->
            (OxmIPDscp (0 land 63), bits2)
        (* IP ECN (2 bits in ToS field). *)
        |  OFPXMT_OFB_IP_ECN ->
            (OxmIPEcn (0 land 3), bits2)
        (* IPv4 source address. *)
        | OFPXMT_OFB_IPV4_SRC ->
          if hm = 1 then
            (OxmIP4Src {m_value = 0l; m_mask = (Some 0l)}, bits2)
          else
            (OxmIP4Src {m_value = 0l; m_mask = None}, bits2)
        (* IPv4 destination address. *)
        | OFPXMT_OFB_IPV4_DST ->
          if hm = 1 then
            (OxmIP4Dst {m_value = 0l; m_mask = (Some 0l)}, bits2)
          else
            (OxmIP4Dst {m_value = 0l; m_mask = None}, bits2)
        (* ARP opcode. *)
        | OFPXMT_OFB_ARP_OP ->
          (OxmARPOp 0, bits2)
        (* ARP source IPv4 address. *)
        | OFPXMT_OFB_ARP_SPA ->
          if hm = 1 then
            (OxmARPSpa {m_value = 0l; m_mask = (Some 0l)}, bits2)
          else
            (OxmARPSpa {m_value = 0l; m_mask = None}, bits2)
        (* ARP target IPv4 address. *)
        | OFPXMT_OFB_ARP_TPA ->
          if hm = 1 then
            (OxmARPTpa {m_value = 0l; m_mask = (Some 0l)}, bits2)
          else
            (OxmARPTpa {m_value = 0l; m_mask = None}, bits2)
        (* ARP source hardware address. *)
        | OFPXMT_OFB_ARP_SHA ->
          if hm = 1 then
            (OxmARPSha {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmARPSha {m_value = 0L; m_mask = None}, bits2)
      (* ARP target hardware address. *)
        | OFPXMT_OFB_ARP_THA ->
          if hm = 1 then
            (OxmARPTha {m_value = 0L; m_mask = (Some 0L)}, bits2)
          else
            (OxmARPTha {m_value = 0L; m_mask = None}, bits2)
        (* ICMP Type *)
        | OFPXMT_OFB_ICMPV4_TYPE ->
            (OxmICMPType 0, bits2)
        (* ICMP code. *)
        |   OFPXMT_OFB_ICMPV4_CODE ->
            (OxmICMPCode 0, bits2)
        | OFPXMT_OFB_TCP_DST ->
          if hm = 1 then
            (OxmTCPDst {m_value = 0; m_mask = (Some 0)}, bits2)
          else
            (OxmTCPDst {m_value = 0; m_mask = None}, bits2)
        | OFPXMT_OFB_TCP_SRC ->
          if hm = 1 then
            (OxmTCPSrc {m_value = 0; m_mask = (Some 0)}, bits2)
          else
            (OxmTCPSrc {m_value = 0; m_mask = None}, bits2)
        | OFPXMT_OFB_MPLS_LABEL ->
            (OxmMPLSLabel 0l, bits2)
        | OFPXMT_OFB_VLAN_PCP ->
            (OxmVlanPcp 0, bits2)
        | OFPXMT_OFB_VLAN_VID ->
          if hm = 1 then
            (OxmVlanVId {m_value = 0; m_mask = (Some 0)}, bits2)
          else
            (OxmVlanVId {m_value = 0; m_mask = None}, bits2)
        | OFPXMT_OFB_MPLS_TC ->
            (OxmMPLSTc 0, bits2)
        | _ -> raise (Unparsable (sprintf "malformed packet in oxm %d\n" (value lsr 1)))

    let rec parse_headers (bits : Cstruct.t) : oxmMatch*Cstruct.t = 
      if Cstruct.len bits < sizeof_ofp_oxm then ([], bits)
      else let field, bits2 = parse_header bits in
      let fields, bits3 = parse_headers bits2 in    
      (List.append [field] fields, bits3)

end

module PseudoPort = struct
  type t = pseudoPort

  cenum ofp_port_no {
    (* Maximum number of physical and logical switch ports. *)
    OFPP_MAX        = 0xffffff00l;

    (* Reserved OpenFlow Port (fake output "ports"). *)
    OFPP_IN_PORT    = 0xfffffff8l; (* Send the packet out the input port. This
                                      reserved port must be explicitly used
                                      in order to send back out of the input
                                      port.*)
    OFPP_TABLE      = 0xfffffff9l; (* Submit the packet to the first flow table
                                      NB: This destination port can only be
                                      used in packet-out messages. *)
    OFPP_NORMAL     = 0xfffffffal; (* Process with normal L2/L3 switching. *)
    OFPP_FLOOD      = 0xfffffffbl; (* All physical ports in VLAN, except input
                                      port and those blocked or link down. *)
    OFPP_ALL        = 0xfffffffcl; (* All physical ports except input port. *)
    OFPP_CONTROLLER = 0xfffffffdl; (* Send to controller. *)
    OFPP_LOCAL      = 0xfffffffel; (* Local openflow "port". *)
    OFPP_ANY        = 0xffffffffl  (* Wildcard port used only for flow mod
                                     (delete) and flow stats requests. Selects
                                     all flows regardless of output port
                                     (including flows with no output port). *)
  } as uint32_t

  let size_of _ = 4

  let to_string (t : t) = 
   match t with
    | PhysicalPort p -> sprintf "%lu" p
    | InPort -> "InPort"
    | Table -> "Table"
    | Normal -> "Normal"
    | Flood -> "Flood"
    | AllPorts -> "AllPorts"
    | Controller n -> sprintf "Controller<%d bytes>" n
    | Local -> "Local"
    | Any -> "Any"

  let marshal (t : t) : int32 = match t with
    | PhysicalPort(p) -> p
    | InPort -> ofp_port_no_to_int OFPP_IN_PORT
    | Table -> ofp_port_no_to_int OFPP_TABLE
    | Normal -> ofp_port_no_to_int OFPP_NORMAL
    | Flood -> ofp_port_no_to_int  OFPP_FLOOD
    | AllPorts -> ofp_port_no_to_int OFPP_ALL
    | Controller(_) -> ofp_port_no_to_int  OFPP_CONTROLLER
    | Local -> ofp_port_no_to_int  OFPP_LOCAL
    | Any -> ofp_port_no_to_int  OFPP_ANY

  let make ofp_port_no_code len =
    match int_to_ofp_port_no ofp_port_no_code with
      | Some OFPP_IN_PORT -> InPort
      | Some OFPP_TABLE -> Table
      | Some OFPP_NORMAL -> Normal
      | Some OFPP_FLOOD -> Flood
      | Some OFPP_ALL -> AllPorts
      | Some OFPP_CONTROLLER -> Controller len
      | Some OFPP_LOCAL -> Local
      | Some OFPP_ANY -> Any
      | _ ->
        if compare_uint32 ofp_port_no_code (ofp_port_no_to_int OFPP_MAX) then
          PhysicalPort ofp_port_no_code
        else
          raise
            (Unparsable (sprintf "unsupported port number (%lu)" ofp_port_no_code))

end

module OfpMatch = struct

  let sizeof (om : oxmMatch) : int =
    let n = sizeof_ofp_match + sum (map Oxm.sizeof om) in
    pad_to_64bits n

  let to_string om = 
    let oxmString = String.concat "\n" (map Oxm.to_string om) in
    Format.sprintf "Match : %s" oxmString

  let marshal (buf : Cstruct.t) (om : oxmMatch) : int =
    let size = sizeof om in
    set_ofp_match_typ buf 1; (* OXPMT_OXM *)
    set_ofp_match_length buf (sizeof_ofp_match + sum (map Oxm.sizeof om)); (* Length of ofp_match (excluding padding) *)
    let buf = Cstruct.shift buf sizeof_ofp_match in
    let oxm_size = marshal_fields buf om Oxm.marshal in
    let pad = size - (sizeof_ofp_match + oxm_size) in
    if pad > 0 then
      let buf = Cstruct.shift buf oxm_size in
      let _ = pad_with_zeros buf pad in
      size
    else size

  let rec parse_fields (bits : Cstruct.t) : oxmMatch * Cstruct.t =
    if Cstruct.len bits <= sizeof_ofp_oxm then ([], bits)
    else let field, bits2 = Oxm.parse bits in
    let fields, bits3 = parse_fields bits2 in
    (List.append [field] fields, bits3)

  let parse (bits : Cstruct.t) : oxmMatch * Cstruct.t =
    let length = get_ofp_match_length bits in
    let oxm_bits = Cstruct.sub bits sizeof_ofp_match (length - sizeof_ofp_match) in
    let fields, _ = parse_fields oxm_bits in
    let bits = Cstruct.shift bits (pad_to_64bits length) in
    (fields, bits)

end

module Action = struct

  type sequence = OpenFlow0x04_Core.actionSequence
    
  let sizeof (act : action) : int = match act with
    | Output _ -> sizeof_ofp_action_output
    | Group _ -> sizeof_ofp_action_group
    | PopVlan -> sizeof_ofp_action_header
    | PushVlan -> sizeof_ofp_action_push
    | PopMpls -> sizeof_ofp_action_pop_mpls
    | PushMpls -> sizeof_ofp_action_push
    | SetField oxm -> pad_to_64bits (sizeof_ofp_action_set_field + Oxm.sizeof oxm)
    | CopyTtlOut -> sizeof_ofp_action_header
    | CopyTtlIn -> sizeof_ofp_action_header
    | SetNwTtl _ -> sizeof_ofp_action_nw_ttl
    | DecNwTtl -> sizeof_ofp_action_header
    | PushPbb -> sizeof_ofp_action_push
    | PopPbb -> sizeof_ofp_action_header
    | SetMplsTtl _ -> sizeof_ofp_action_push
    | DecMplsTtl -> sizeof_ofp_action_header
    | SetQueue _ -> sizeof_ofp_action_set_queue
    | Experimenter _ -> sizeof_ofp_action_experimenter

  let to_type t : actionTyp = 
    match (int_to_ofp_action_type t) with
      | Some OFPAT_OUTPUT -> Output
      | Some OFPAT_COPY_TTL_OUT -> CopyTTLOut
      | Some OFPAT_COPY_TTL_IN -> CopyTTLIn
      | Some OFPAT_SET_MPLS_TTL -> SetMPLSTTL
      | Some OFPAT_DEC_MPLS_TTL -> DecMPLSTTL
      | Some OFPAT_PUSH_VLAN -> PushVLAN
      | Some OFPAT_POP_VLAN -> PopVLAN
      | Some OFPAT_PUSH_MPLS -> PushMPLS
      | Some OFPAT_POP_MPLS -> PopMPLS
      | Some OFPAT_SET_QUEUE -> SetQueue
      | Some OFPAT_GROUP -> Group
      | Some OFPAT_SET_NW_TTL -> SetNWTTL
      | Some OFPAT_DEC_NW_TTL -> DecNWTTL
      | Some OFPAT_SET_FIELD -> SetField
      | Some OFPAT_PUSH_PBB -> PushPBB
      | Some OFPAT_POP_PBB -> PopPBB
      | Some OFPAT_EXPERIMENTER -> Experimenter
      | None -> failwith "None type"

  let marshal (buf : Cstruct.t) (act : action) : int =
    let size = sizeof act in
    match act with
      | Output port ->
        set_ofp_action_output_typ buf 0; (* OFPAT_OUTPUT *)
        set_ofp_action_output_len buf size;
        set_ofp_action_output_port buf (PseudoPort.marshal port);
        set_ofp_action_output_max_len buf
          (match port with
            | Controller max_len -> max_len
            | _ -> 0);
        set_ofp_action_output_pad0 buf 0;
        set_ofp_action_output_pad1 buf 0;
        set_ofp_action_output_pad2 buf 0;
        set_ofp_action_output_pad3 buf 0;
        set_ofp_action_output_pad4 buf 0;
        set_ofp_action_output_pad5 buf 0;
        size
      | PushVlan ->
	set_ofp_action_push_typ buf 17; (* PUSH_VLAN *)
	set_ofp_action_push_len buf size;
	set_ofp_action_push_ethertype buf 0x8100;
	size
      | PopVlan ->
	set_ofp_action_header_typ buf 18; (* POP_VLAN *)
	set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
	size
      | PushMpls ->
	set_ofp_action_push_typ buf 19; (* PUSH_MPLS *)
	set_ofp_action_push_len buf size;
	set_ofp_action_push_ethertype buf 0x8847;
	size
      | PopMpls ->
	set_ofp_action_pop_mpls_typ buf 20; (* POP_MPLS *)
	set_ofp_action_pop_mpls_len buf size;
	set_ofp_action_pop_mpls_ethertype buf 0x800;
	size
      | Group gid ->
        set_ofp_action_group_typ buf 22; (* OFPAT_GROUP *)
        set_ofp_action_group_len buf size;
        set_ofp_action_group_group_id buf gid;
        size
      | SetField oxm ->
        set_ofp_action_set_field_typ buf 25; (* OFPAT_SET_FIELD *)
        set_ofp_action_set_field_len buf size;
        let buf = Cstruct.shift buf sizeof_ofp_action_set_field in
        let oxm_size = Oxm.marshal buf oxm in
        let pad = size - (sizeof_ofp_action_set_field + oxm_size) in
        (* printf "pad = %d\n" pad; *)
        if pad > 0 then
          let buf = Cstruct.shift buf oxm_size in
          let _ = pad_with_zeros buf pad in
          size
        else size
      | CopyTtlOut ->
        set_ofp_action_header_typ buf 11; (* OFPAT_COPY_TTL_OUT *)
        set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
        size
      | CopyTtlIn ->
        set_ofp_action_header_typ buf 12; (* OFPAT_COPY_TTL_IN *)
        set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
        size
      | SetNwTtl newTtl ->
        set_ofp_action_nw_ttl_typ buf 23; (* OFPAT_SET_NW_TTL *)
        set_ofp_action_nw_ttl_len buf size;
        set_ofp_action_nw_ttl_nw_ttl buf newTtl;
        set_ofp_action_nw_ttl_pad buf 0;
        set_ofp_action_nw_ttl_pad1 buf 0;
        set_ofp_action_nw_ttl_pad2 buf 0;
        size
      | DecNwTtl ->
        set_ofp_action_header_typ buf 24; (* OFPAT_DEC_NW_TTL *)
        set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
        size
      | PushPbb ->
        set_ofp_action_push_typ buf 26; (* OFPAT_PUSH_PBB *)
        set_ofp_action_push_len buf size;
        set_ofp_action_push_ethertype buf 0x88a8; (* Not sure, maybe need to redefine*)
        size
      | PopPbb ->
        set_ofp_action_header_typ buf 27; (* OFPAT_POP_PBB *)
        set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
        size
      | SetMplsTtl newTtl ->
        set_ofp_action_mpls_ttl_typ buf 15; (* OFPAT_SET_MPLS_TTL *)
        set_ofp_action_mpls_ttl_len buf size;
        set_ofp_action_mpls_ttl_mpls_ttl buf newTtl;
        size
      | DecMplsTtl ->
        set_ofp_action_header_typ buf 16; (* OFPAT_DEC_MPLS_TTL *)
        set_ofp_action_header_len buf size;
        set_ofp_action_header_pad buf 0;
        set_ofp_action_header_pad1 buf 0;
        set_ofp_action_header_pad2 buf 0;
        set_ofp_action_header_pad3 buf 0;
        size
      | SetQueue queueId ->
        set_ofp_action_set_queue_typ buf 21; (* OFPAT_SET_QUEUE *)
        set_ofp_action_set_queue_len buf size;
        set_ofp_action_set_queue_queue_id buf queueId;
        size
      | Experimenter exp ->
        set_ofp_action_experimenter_typ buf 0xffff; (* OFPAT_EXPERIMENTER *)
        set_ofp_action_experimenter_len buf size;
        set_ofp_action_experimenter_experimenter buf exp;
        size

  let parse (bits : Cstruct.t) : action =
    match to_type (get_ofp_action_header_typ bits) with
     | Output -> Output (PseudoPort.make (get_ofp_action_output_port bits) 
     (get_ofp_action_output_max_len bits))
     | Group -> Group (get_ofp_action_group_group_id bits)
     | PushVLAN -> PushVlan
     | PopVLAN -> PopVlan
     | PushMPLS -> PushMpls
     | PopMPLS -> PopMpls
     | SetField -> let field,_ = Oxm.parse (
     Cstruct.shift bits 4) in (*TEST BECAUSE OF WRONG OFFSET??*)
     SetField (field)
     | CopyTTLOut -> CopyTtlOut
     | CopyTTLIn -> CopyTtlIn
     | SetMPLSTTL -> SetMplsTtl (get_ofp_action_mpls_ttl_mpls_ttl bits)
     | DecMPLSTTL -> DecMplsTtl
     | SetQueue -> SetQueue (get_ofp_action_set_queue_queue_id bits)
     | SetNWTTL -> SetNwTtl (get_ofp_action_nw_ttl_nw_ttl bits)
     | DecNWTTL -> DecNwTtl
     | PushPBB -> PushPbb
     | PopPBB  -> PopPbb
     | Experimenter -> Experimenter (get_ofp_action_experimenter_experimenter bits)

  let rec parse_fields (bits : Cstruct.t) : sequence * Cstruct.t =
    if Cstruct.len bits < sizeof_ofp_action_header then ([], bits)
    else let field = parse bits in
    let bits2 = Cstruct.shift bits (sizeof field) in
    let fields, bits3 = parse_fields bits2 in
    (List.append [field] fields, bits3)

  let parse_sequence (bits : Cstruct.t) : sequence =
    let fields, _ = parse_fields bits in
    fields

  let to_string seq =
      match seq with
        | Output o -> Format.sprintf "PseudoPort: %s" (PseudoPort.to_string o)
        | Group g -> Format.sprintf "Group ID: %lu" g
        | PopVlan -> "Pop Vlan"
        | PushVlan -> "Push Vlan"
        | PopMpls -> "Pop Mpls"
        | PushMpls -> "Push Mpls"
        | SetField oxm -> Format.sprintf "oxm: %s" (Oxm.to_string oxm)
        | CopyTtlOut -> "Copy TTL out"
        | CopyTtlIn -> "Copy TTL In"
        | SetNwTtl t -> Format.sprintf "Set NW TTL %u" t
        | DecNwTtl -> "Dec NW TTL"
        | PushPbb -> "Push PBB"
        | PopPbb -> "POP PBB"
        | SetMplsTtl t -> Format.sprintf "Set MPLS TTL: %u" t
        | DecMplsTtl -> "Dec MPLS TTL"
        | SetQueue q -> Format.sprintf "Set Queue: %lu" q
        | Experimenter e -> Format.sprintf "Experimenter: %lu" e
end

module Bucket = struct

  let sizeof (bucket : bucket) : int =
    let n = sizeof_ofp_bucket + sum (map Action.sizeof bucket.bu_actions) in
    pad_to_64bits n

  let marshal (buf : Cstruct.t) (bucket : bucket) : int =
    let size = sizeof bucket in
    set_ofp_bucket_len buf size;
    set_ofp_bucket_weight buf bucket.bu_weight;
    set_ofp_bucket_watch_port buf
      (match bucket.bu_watch_port with
        | None -> ofpg_any
        | Some port -> port);
    set_ofp_bucket_watch_group buf
      (match bucket.bu_watch_group with
        | None -> ofpg_any
        | Some group_id -> group_id);
    set_ofp_bucket_pad0 buf 0;
    set_ofp_bucket_pad1 buf 0;
    set_ofp_bucket_pad2 buf 0;
    set_ofp_bucket_pad3 buf 0;
    let action_marshal buf act =
      match act with
        | Output Table ->
          failwith "OFPP_TABLE not allowed in installed flow"
        | _ -> Action.marshal buf act in
    let buf = Cstruct.shift buf sizeof_ofp_bucket in
    sizeof_ofp_bucket + (marshal_fields buf bucket.bu_actions action_marshal)
end

module FlowModCommand = struct
    
  type t = flowModCommand

  let n = ref 0L
  
  let sizeof _ = 1

  let marshal (t : t) : int = match t with
    | AddFlow -> n := Int64.succ !n; ofp_flow_mod_command_to_int OFPFC_ADD
    | ModFlow -> ofp_flow_mod_command_to_int OFPFC_MODIFY
    | ModStrictFlow -> ofp_flow_mod_command_to_int OFPFC_MODIFY_STRICT
    | DeleteFlow -> ofp_flow_mod_command_to_int OFPFC_DELETE
    | DeleteStrictFlow -> ofp_flow_mod_command_to_int OFPFC_DELETE_STRICT

  let parse bits : flowModCommand = 
    match (int_to_ofp_flow_mod_command bits) with
      | Some OFPFC_ADD -> AddFlow
      | Some OFPFC_MODIFY -> ModFlow
      | Some OFPFC_MODIFY_STRICT -> ModStrictFlow
      | Some OFPFC_DELETE -> DeleteFlow
      | Some OFPFC_DELETE_STRICT -> DeleteStrictFlow
      | None -> raise (Unparsable (sprintf "malformed command"))

  let to_string t = 
   match t with
    | AddFlow -> "Add"
    | ModFlow -> "Modify"
    | ModStrictFlow -> "ModifyStrict"
    | DeleteFlow -> "Delete"
    | DeleteStrictFlow -> "DeleteStrict"
end

module GroupType = struct
    
  type t = groupType

  let n = ref 0L

  let marshal (t : t) : int = match t with
    | All -> ofp_group_type_to_int OFPGC_ALL
    | Select -> ofp_group_type_to_int OFPGC_SELECT
    | Indirect -> ofp_group_type_to_int OFPGC_INDIRECT
    | FF -> ofp_group_type_to_int OFPGC_FF
     
end

module GroupMod = struct

  let sizeof (gm: groupMod) : int =
    match gm with
      | AddGroup (typ, gid, buckets) -> 
        sizeof_ofp_group_mod + sum (map Bucket.sizeof buckets)
      | DeleteGroup (typ, gid) -> 
        sizeof_ofp_group_mod

  let marshal (buf : Cstruct.t) (gm : groupMod) : int =
    match gm with
      | AddGroup (typ, gid, buckets) -> 
        set_ofp_group_mod_command buf 0; (* OFPGC_ADD *)
        set_ofp_group_mod_typ buf (GroupType.marshal typ);
        set_ofp_group_mod_pad buf 0;
        set_ofp_group_mod_group_id buf gid;
        sizeof_ofp_group_mod + (marshal_fields (Cstruct.shift buf sizeof_ofp_group_mod) buckets Bucket.marshal)
      | DeleteGroup (typ, gid) ->
        set_ofp_group_mod_command buf 2; (* OFPGC_DEL *)
        set_ofp_group_mod_typ buf (GroupType.marshal typ);
        set_ofp_group_mod_pad buf 0;
        set_ofp_group_mod_group_id buf gid;
        sizeof_ofp_group_mod
end

module Instruction = struct

  let to_string ins =
    match ins with
      | GotoTable t -> Format.sprintf "Go to Table: %u" t
      | ApplyActions actions -> Format.sprintf "Apply Actions: \n%s"
                                (String.concat "\n" (map Action.to_string actions))
      | WriteActions actions -> Format.sprintf "Write Actions: \n%s" 
                                (String.concat "\n" (map Action.to_string actions))
      | WriteMetadata meta -> 
        (match meta.m_mask with
          | None -> Format.sprintf "WriteMeta : %LX" meta.m_value
          | Some m -> Format.sprintf "WriteMeta : %LX/%LX" meta.m_value m)
      | Clear -> "Clear"
      | Meter m -> Format.sprintf "Meter : %lu" m
      | Experimenter e -> Format.sprintf "Experimenter : %lu" e

  let sizeof (ins : instruction) : int =
    match ins with
      | GotoTable _ ->
        sizeof_ofp_instruction_goto_table
      | ApplyActions actions ->
        sizeof_ofp_instruction_actions + sum (map Action.sizeof actions)
      | WriteActions actions ->
        sizeof_ofp_instruction_actions + sum (map Action.sizeof actions)
      | WriteMetadata _ -> sizeof_ofp_instruction_write_metadata
      | Clear -> sizeof_ofp_instruction_actions
      | Meter _ -> sizeof_ofp_instruction_meter
      | Experimenter _ -> sizeof_ofp_instruction_experimenter

  let marshal (buf : Cstruct.t) (ins : instruction) : int =
    let size = sizeof ins in
      match ins with
        | GotoTable table_id ->
          set_ofp_instruction_goto_table_typ buf 1; (* OFPIT_GOTO_TABLE *)
          set_ofp_instruction_goto_table_len buf size;
          set_ofp_instruction_goto_table_table_id buf table_id;
          set_ofp_instruction_goto_table_pad0 buf 0;
          set_ofp_instruction_goto_table_pad1 buf 0;
          set_ofp_instruction_goto_table_pad2 buf 0;
          size
        | WriteActions actions ->
          set_ofp_instruction_actions_typ buf 3; (* OFPIT_WRITE_ACTIONS *)
          set_ofp_instruction_actions_len buf size;
          set_ofp_instruction_actions_pad0 buf 0;
          set_ofp_instruction_actions_pad1 buf 0;
          set_ofp_instruction_actions_pad2 buf 0;
          set_ofp_instruction_actions_pad3 buf 0;
          sizeof_ofp_instruction_actions + (
          marshal_fields 
          (Cstruct.shift buf sizeof_ofp_instruction_actions)
          actions
          Action.marshal)
        | ApplyActions actions ->
          set_ofp_instruction_actions_typ buf 4; (* OFPIT_APPLY_ACTIONS *)
          set_ofp_instruction_actions_len buf size;
          set_ofp_instruction_actions_pad0 buf 0;
          set_ofp_instruction_actions_pad1 buf 0;
          set_ofp_instruction_actions_pad2 buf 0;
          set_ofp_instruction_actions_pad3 buf 0;
          sizeof_ofp_instruction_actions + (marshal_fields (Cstruct.shift buf sizeof_ofp_instruction_actions) actions Action.marshal)
        | WriteMetadata metadata ->
          set_ofp_instruction_write_metadata_typ buf 2; (* OFPIT_WRITE_METADATA *)
          set_ofp_instruction_write_metadata_len buf size;
          set_ofp_instruction_write_metadata_pad0 buf 0;
          set_ofp_instruction_write_metadata_pad1 buf 0;
          set_ofp_instruction_write_metadata_pad2 buf 0;
          set_ofp_instruction_write_metadata_pad3 buf 0;
          set_ofp_instruction_write_metadata_metadata buf metadata.m_value;
          set_ofp_instruction_write_metadata_metadata_mask buf (
            match metadata.m_mask with
              | None -> 0L
              | Some mask -> mask);
          size
        | Clear -> 
          set_ofp_instruction_actions_typ buf 5; (* OFPIT_CLEAR_ACTIONS *)
          set_ofp_instruction_actions_len buf size;
          set_ofp_instruction_actions_pad0 buf 0;
          set_ofp_instruction_actions_pad1 buf 0;
          set_ofp_instruction_actions_pad2 buf 0;
          set_ofp_instruction_actions_pad3 buf 0;
          size
        | Meter meterId->
          set_ofp_instruction_meter_typ buf 6; (* OFPIT_METER *)
          set_ofp_instruction_meter_len buf size;
          set_ofp_instruction_meter_meter_id buf meterId;
          size
        | Experimenter experimenterId->
          set_ofp_instruction_experimenter_typ buf 0xffff; (* OFPIT_EXPERIMENTER *)
          set_ofp_instruction_experimenter_len buf size;
          set_ofp_instruction_experimenter_experimenter buf experimenterId;
          size


  let parse (bits : Cstruct.t) : instruction =
    let typ = get_ofp_instruction_typ bits in
    let len = get_ofp_instruction_len bits in
      match (int_to_ofp_instruction_type typ) with
        | Some OFPIT_GOTO_TABLE -> GotoTable (
        get_ofp_instruction_goto_table_table_id bits)
        | Some OFPIT_WRITE_METADATA -> 
            let value = get_ofp_instruction_write_metadata_metadata bits in 
            let mask = get_ofp_instruction_write_metadata_metadata_mask bits in
            if mask <> 0L then
              WriteMetadata ({m_value = value; m_mask = Some mask})
            else
              WriteMetadata ({m_value = value; m_mask = None})
        | Some OFPIT_WRITE_ACTIONS -> WriteActions (
        Action.parse_sequence (Cstruct.sub bits sizeof_ofp_instruction_actions (len-sizeof_ofp_instruction_actions)))
        | Some OFPIT_APPLY_ACTIONS -> ApplyActions (
        Action.parse_sequence (Cstruct.sub bits sizeof_ofp_instruction_actions (len-sizeof_ofp_instruction_actions))) 
        | Some OFPIT_CLEAR_ACTIONS -> Clear
        | Some OFPIT_METER -> Meter (get_ofp_instruction_meter_meter_id bits)
        | Some OFPIT_EXPERIMENTER -> Experimenter (
        get_ofp_instruction_experimenter_experimenter bits)
        | _ -> raise (Unparsable (sprintf "Unkown instruction message"))
        
end

module Instructions = struct

  let sizeof (inss : instruction list) : int =
    sum (map Instruction.sizeof inss)

  let marshal (buf : Cstruct.t) (inss : instruction list) : int =
    if sizeof inss <> 0 then
      marshal_fields buf inss Instruction.marshal
    else 0

  let rec parse_field (bits : Cstruct.t) : instruction list*Cstruct.t =
    if Cstruct.len bits < sizeof_ofp_instruction then [],bits
    else let field = Instruction.parse bits in
    let bits2 = Cstruct.shift bits (Instruction.sizeof field) in
    let fields, bits3 = parse_field bits2 in
    (List.append [field] fields, bits3)

  let to_string ins =
    let insString = String.concat "\n" (map Instruction.to_string ins) in
    insString

  let parse (bits : Cstruct.t) : instruction list =
    let field,_ = parse_field bits in
    field

end

module FlowMod = struct

  let sizeof (fm : flowMod) =
    sizeof_ofp_flow_mod + (OfpMatch.sizeof fm.mfOfp_match) + (Instructions.sizeof fm.mfInstructions)

  let flags_to_int (f : flowModFlags) =
    (if f.fmf_send_flow_rem then 1 lsl 0 else 0) lor
      (if f.fmf_check_overlap then 1 lsl 1 else 0) lor
        (if f.fmf_reset_counts then 1 lsl 2 else 0) lor
          (if f.fmf_no_pkt_counts then 1 lsl 3 else 0) lor
            (if f.fmf_no_byt_counts then 1 lsl 4 else 0)

  let int_to_flags bits : flowModFlags =
  { fmf_send_flow_rem = test_bit16  0 bits
  ; fmf_check_overlap = test_bit16  1 bits
  ; fmf_reset_counts = test_bit16  2 bits
  ; fmf_no_pkt_counts = test_bit16  3 bits
  ; fmf_no_byt_counts = test_bit16  4 bits
  }

  let flags_to_string f =
  Format.sprintf "SendFlowRem:%b;CheckOverlap:%b;ResetCount:%b;\
                 NoPktCount:%b;NoBytCount:%b"
                 f.fmf_send_flow_rem
                 f.fmf_check_overlap
                 f.fmf_reset_counts
                 f.fmf_no_pkt_counts
                 f.fmf_no_byt_counts

  let marshal (buf : Cstruct.t) (fm : flowMod) : int =
    set_ofp_flow_mod_cookie buf fm.mfCookie.m_value;
    set_ofp_flow_mod_cookie_mask buf (
      match fm.mfCookie.m_mask with
        | None -> 0L
        | Some mask -> mask);
    set_ofp_flow_mod_table_id buf fm.mfTable_id;
    set_ofp_flow_mod_command buf (FlowModCommand.marshal fm.mfCommand);
    set_ofp_flow_mod_idle_timeout buf
      (match fm.mfIdle_timeout with
        | Permanent -> 0
        | ExpiresAfter value -> value);
    set_ofp_flow_mod_hard_timeout buf
      (match fm.mfHard_timeout with
        | Permanent -> 0
        | ExpiresAfter value -> value);
    set_ofp_flow_mod_priority buf fm.mfPriority;
    set_ofp_flow_mod_buffer_id buf
      (match fm.mfBuffer_id with
        | None -> ofp_no_buffer
        | Some bid -> bid);
    set_ofp_flow_mod_out_port buf
      (match fm.mfOut_port with
        | None -> 0l
        | Some port -> PseudoPort.marshal port);
    set_ofp_flow_mod_out_group buf
      (match fm.mfOut_group with
        | None -> 0l
        | Some gid -> gid);
    set_ofp_flow_mod_flags buf (flags_to_int fm.mfFlags);
    set_ofp_flow_mod_pad0 buf 0;
    set_ofp_flow_mod_pad1 buf 0;

    let size = sizeof_ofp_flow_mod +
        OfpMatch.marshal 
         (Cstruct.sub buf sizeof_ofp_flow_mod (OfpMatch.sizeof fm.mfOfp_match))
         fm.mfOfp_match in
      size + Instructions.marshal (Cstruct.shift buf size) fm.mfInstructions

  let parse (bits : Cstruct.t) : flowMod =
    let mfMask = get_ofp_flow_mod_cookie_mask bits in
    let mfCookie =
      if mfMask <> 0L then
        {m_value = get_ofp_flow_mod_cookie bits;
        m_mask = (Some (get_ofp_flow_mod_cookie_mask bits))}
    else {m_value = get_ofp_flow_mod_cookie bits;
        m_mask = None}
      in
    let mfTable_id = get_ofp_flow_mod_table_id bits in
    let mfCommand = FlowModCommand.parse (get_ofp_flow_mod_command bits) in
    let mfIdle_timeout = match (get_ofp_flow_mod_idle_timeout bits) with
                         | 0 -> Permanent 
                         | n -> ExpiresAfter n in
    let mfHard_timeout = match (get_ofp_flow_mod_hard_timeout bits) with
                         | 0 -> Permanent 
                         | n -> ExpiresAfter n in
    let mfPriority = get_ofp_flow_mod_priority bits in
    let mfBuffer_id = match (get_ofp_flow_mod_buffer_id bits) with
        | 0xffffffffl -> None
        | n -> Some n in
    let mfOut_port = match (get_ofp_flow_mod_out_port bits) with
        | 0l -> None
        | _ -> Some (PseudoPort.make (get_ofp_flow_mod_out_port bits) 0) in
    let mfOut_group = match (get_ofp_flow_mod_out_group bits) with
        | 0l -> None
        | n -> Some n in
    let mfFlags = int_to_flags (get_ofp_flow_mod_flags bits) in
    let mfOfp_match,instructionsBits = OfpMatch.parse (Cstruct.shift bits sizeof_ofp_flow_mod) in
    let mfInstructions = Instructions.parse instructionsBits in
    { mfCookie; mfTable_id;
      mfCommand; mfIdle_timeout;
      mfHard_timeout; mfPriority;
      mfBuffer_id;
      mfOut_port;
      mfOut_group; mfFlags;
      mfOfp_match; mfInstructions}
  
  let to_string (flow : flowMod) =
    Format.sprintf 
"cookie:%s;
table:%u;
command:%s;
IdleTimeout:%s;
HardTimeout:%s;
priority:%u;
bufferId:%s;
outPort:%s;
outGroup:%s;
flags:%s;
match:%s;
instructions:%s\n"
    (match flow.mfCookie.m_mask with
        | None -> Int64.to_string flow.mfCookie.m_value
        | Some m -> Format.sprintf "%LX/%LX" flow.mfCookie.m_value m)
    flow.mfTable_id
    (FlowModCommand.to_string flow.mfCommand)
    (match flow.mfIdle_timeout with
        | Permanent -> "Permanent"
        | ExpiresAfter t-> string_of_int t)
    (match flow.mfHard_timeout with
        | Permanent -> "Permanent"
        | ExpiresAfter t-> string_of_int t)
    flow.mfPriority
    (match flow.mfBuffer_id with
        | None -> "None"
        | Some t -> Int32.to_string t)
    (match flow.mfOut_port with
        | None -> "None"
        | Some t -> PseudoPort.to_string t)
    (match flow.mfOut_group with
        | None -> "None"
        | Some t -> Int32.to_string t)
    (flags_to_string flow.mfFlags)
    (OfpMatch.to_string flow.mfOfp_match)
    (Instructions.to_string flow.mfInstructions)
end

module Capabilities = struct

  let to_int32 (capa : capabilities) : int32 = 
    Int32.logor (if capa.flow_stats then (Int32.shift_left 1l 0) else 0l)
     (Int32.logor (if capa.table_stats then (Int32.shift_left 1l 1) else 0l)
      (Int32.logor (if capa.port_stats then (Int32.shift_left 1l 2) else 0l)
       (Int32.logor (if capa.group_stats then (Int32.shift_left 1l 3) else 0l)
        (Int32.logor (if capa.ip_reasm then (Int32.shift_left 1l 5) else 0l)
         (Int32.logor (if capa.queue_stats then (Int32.shift_left 1l 6) else 0l)
           (if capa.port_blocked then (Int32.shift_left 1l 7) else 0l))))))

  let to_string (cap : capabilities) : string =
      Format.sprintf "Port Blocked:%B\nQueue Stats:%B\nIP Reasm:%B\nGroup Stats:%B\nPort Stats:%B\nTable Stats:%B\nFlow Stats:%B"
      cap.port_blocked
      cap.queue_stats
      cap.ip_reasm
      cap.group_stats
      cap.port_stats
      cap.table_stats
      cap.flow_stats

  let parse (bits : int32) : capabilities =
    { port_blocked = Bits.test_bit 7 bits;
      queue_stats = Bits.test_bit 6 bits;
      ip_reasm = Bits.test_bit 5 bits;
      group_stats = Bits.test_bit 3 bits;
      port_stats = Bits.test_bit 2 bits;
      table_stats = Bits.test_bit 1 bits;
      flow_stats = Bits.test_bit 0 bits;
    }

end

module SwitchFeatures = struct

  type t = { datapath_id : int64; num_buffers : int32;
             num_tables : int8; aux_id : int8;
             supported_capabilities : capabilities }

  let sizeof (sw : t) : int =
      sizeof_ofp_switch_features

  let to_string (sw : t) : string =
      Format.sprintf "Datapath ID: %Lu\nNum Buffers: %lu\nNum Tables: %u\nAux ID: %u\nCapabilities: %s"
      sw.datapath_id
      sw.num_buffers
      sw.num_tables
      sw.aux_id
      (Capabilities.to_string sw.supported_capabilities)

  let marshal (buf : Cstruct.t) (features : t) : int =
    set_ofp_switch_features_datapath_id buf features.datapath_id;
    set_ofp_switch_features_n_buffers buf features.num_buffers;
    set_ofp_switch_features_n_tables buf features.num_tables;
    set_ofp_switch_features_auxiliary_id buf features.aux_id;
    set_ofp_switch_features_pad0 buf 0;
    set_ofp_switch_features_pad1 buf 0;
    set_ofp_switch_features_pad2 buf 0;
    set_ofp_switch_features_capabilities buf (Capabilities.to_int32 features.supported_capabilities); 
    sizeof_ofp_switch_features

  let parse (bits : Cstruct.t) : t =
    let datapath_id = get_ofp_switch_features_datapath_id bits in 
    let num_buffers = get_ofp_switch_features_n_buffers bits in
    let num_tables = get_ofp_switch_features_n_tables bits in
    let aux_id = get_ofp_switch_features_auxiliary_id bits in
    let supported_capabilities = Capabilities.parse
      (get_ofp_switch_features_capabilities bits) in
    { datapath_id; 
      num_buffers; 
      num_tables;
      aux_id; 
      supported_capabilities }

end


module PortState = struct

  let state_to_int (state : portState) : int32 =
    Int32.logor (if state.link_down then (Int32.shift_left 1l 0) else 0l) 
     (Int32.logor (if state.blocked then (Int32.shift_left 1l 1) else 0l)  
      (if state.live then (Int32.shift_left 1l 2) else 0l))

  let marshal (ps : portState) : int32 = state_to_int ps

  let parse bits : portState =
    { link_down = Bits.test_bit 0 bits;
      blocked = Bits.test_bit 1 bits;
      live = Bits.test_bit 2 bits
    }

  let to_string (state : portState) =
    Format.sprintf "link_down:%b,blocked:%b,live:%b"
    state.link_down
    state.blocked
    state.live
end

module PortDesc = struct

  let sizeof (_ : portDesc) =
  sizeof_ofp_port

  let marshal (buf : Cstruct.t) (desc : portDesc) : int =
    let size = sizeof_ofp_port in
    set_ofp_port_port_no buf desc.port_no;
    set_ofp_port_pad buf 0l;
    (* set_ofp_port_hw_addr NIY *)
    set_ofp_port_pad2 buf 0;
    set_ofp_port_pad3 buf 0;
    (* set_ofp_port_name NIY *)
    set_ofp_port_config buf (PortConfig.marshal desc.config);
    set_ofp_port_state buf (PortState.marshal desc.state);
    set_ofp_port_curr buf (PortFeatures.marshal desc.curr);
    set_ofp_port_advertised buf (PortFeatures.marshal desc.advertised);
    set_ofp_port_supported buf (PortFeatures.marshal desc.supported);
    set_ofp_port_peer buf (PortFeatures.marshal desc.peer);
    (* set_ofp_port_curr_speed NIY *)
    (* set_ofp_port_max_speed NIY *)
    size
	    
  let parse (bits : Cstruct.t) : portDesc =
    let port_no = get_ofp_port_port_no bits in
    let state = PortState.parse (get_ofp_port_state bits) in
    let config = PortConfig.parse (get_ofp_port_config bits) in
    let curr = PortFeatures.parse (get_ofp_port_curr bits) in
    let advertised = PortFeatures.parse (get_ofp_port_advertised bits) in
    let supported = PortFeatures.parse (get_ofp_port_supported bits) in
    let peer = PortFeatures.parse (get_ofp_port_peer bits) in
    { port_no;
      (* hw_addr; *)
      (* name; *)
      config; 
      state;
      curr;
      advertised;
      supported;
      peer
      (* curr_speed; *)
      (* max_speed *) }

  let to_string (port : portDesc) =
    Format.sprintf 
        "port_no:%lu,config:%s,state:%s,curr:%s,advertised:%s\
        supported:%s,peer:%s"
        port.port_no
        (PortConfig.to_string port.config)
        (PortState.to_string port.state)
        (PortFeatures.to_string port.curr)
        (PortFeatures.to_string port.advertised)
        (PortFeatures.to_string port.supported)
        (PortFeatures.to_string port.peer)
        
end

module PortStatus = struct

  let sizeof (_ : portStatus) : int = 
    sizeof_ofp_port_status + sizeof_ofp_port

  let reason_to_int (pr : portReason) : int =
     match pr with
      | PortAdd -> ofp_port_reason_to_int OFPPR_ADD
      | PortDelete -> ofp_port_reason_to_int OFPPR_DELETE
      | PortModify -> ofp_port_reason_to_int OFPPR_MODIFY

  let marshal (buf : Cstruct.t) (status : portStatus) : int =
    set_ofp_port_status_reason buf (reason_to_int status.reason);
    let size = sizeof_ofp_port_status + 
        PortDesc.marshal (Cstruct.shift buf sizeof_ofp_port_status) status.desc in
    size

  let parse (bits : Cstruct.t) : portStatus =
    let reason = (match int_to_ofp_port_reason (get_ofp_port_status_reason bits) with
                    | Some OFPPR_ADD -> PortAdd
                    | Some OFPPR_DELETE -> PortDelete
                    | Some OFPPR_MODIFY -> PortModify
                    | None -> raise (Unparsable (sprintf "unexpected port reason"))) in 
    let bits = Cstruct.shift bits sizeof_ofp_port_status in
    let desc = PortDesc.parse bits in
    { reason;
      desc }
      
  let to_string (t : portStatus) = 
    let reason_to_string (reason : portReason) = match reason with
        | PortAdd -> "Port Add"
        | PortDelete -> "Port Delete"
        | PortModify -> "Port Modify" in
    Format.sprintf 
        "reason : %s,\ndesc : %s"
        (reason_to_string t.reason)
        (PortDesc.to_string t.desc)
end

module PacketIn = struct

 cenum reasonType {
   NO_MATCH = 0;
   ACTION = 1;
   INVALID_TTL = 2
 } as uint8_t

 cstruct ofp_packet_in {
   uint32_t buffer_id;     
   uint16_t total_len;     
   uint8_t reason;         
   uint8_t table_id;
   uint64_t cookie
  } as big_endian

  (* have to check this part, (and in marshal too, not sure of the correctness *)
  let sizeof (pi : packetIn) : int = 
    pi.pi_total_len + (OfpMatch.sizeof pi.pi_ofp_match) + sizeof_ofp_packet_in + 2 (*2 bytes of pad*)

  let to_string (pi: packetIn) : string =
    Format.sprintf "Total Len: %u\nReason: %s\nTable ID:%u\nCookie:%Lu\nOfmPatch:%s\nPayload:%s"
    pi.pi_total_len
    (match pi.pi_reason with
      | NoMatch -> "NO_MATCH"
      | ExplicitSend -> "ACTION"
      | InvalidTTL -> "INVALID_TTL")
    pi.pi_table_id
    pi.pi_cookie
    (OfpMatch.to_string pi.pi_ofp_match)
    (match pi.pi_payload with 
      | Buffered (n,bytes) -> Format.sprintf "Buffered %lu:%s, len:%u" n (Cstruct.to_string bytes) (Cstruct.len bytes)
      | NotBuffered bytes -> Format.sprintf "NotBuffered: %s, len: %u" (Cstruct.to_string bytes) (Cstruct.len bytes))
    


  let marshal (buf : Cstruct.t) (pi : packetIn) : int = 
    let bufMatch = Cstruct.shift buf sizeof_ofp_packet_in in
    let size = pi.pi_total_len + (OfpMatch.marshal bufMatch pi.pi_ofp_match) + 
               sizeof_ofp_packet_in in
    let buffer_id,bytes = match pi.pi_payload with
     | Buffered (n,bytes) -> n, bytes
     | NotBuffered bytes -> -1l, bytes in
    set_ofp_uint8_value (Cstruct.shift bufMatch (OfpMatch.sizeof pi.pi_ofp_match)) 0; (*pad*)
    set_ofp_uint8_value (Cstruct.shift bufMatch (OfpMatch.sizeof pi.pi_ofp_match + 1)) 0; (*pad*)
    Cstruct.blit bytes 0 bufMatch (2 + OfpMatch.sizeof pi.pi_ofp_match) pi.pi_total_len;
    set_ofp_packet_in_buffer_id buf buffer_id;
    set_ofp_packet_in_total_len buf pi.pi_total_len;
    set_ofp_packet_in_reason buf
      (match pi.pi_reason with
         | NoMatch -> reasonType_to_int NO_MATCH
         | ExplicitSend -> reasonType_to_int ACTION
         | InvalidTTL -> reasonType_to_int INVALID_TTL);
    set_ofp_packet_in_table_id buf pi.pi_table_id;
    set_ofp_packet_in_cookie buf pi.pi_cookie;
    size

  let parse (bits : Cstruct.t) : packetIn =
    (* let oc = open_out "test-msg-1.3-msg3-bits" in *)
    (* let str = Cstruct.to_string bits in *)
    (* fprintf oc "%s" str; *)
    (* close_out oc; *)
    let bufId = match get_ofp_packet_in_buffer_id bits with
      | -1l -> None
      | n -> Some n in
    let total_len = get_ofp_packet_in_total_len bits in
    let reason_code = get_ofp_packet_in_reason bits in
    let reason = match int_to_reasonType reason_code with
      | Some NO_MATCH -> NoMatch
      | Some ACTION -> ExplicitSend
      | Some INVALID_TTL -> InvalidTTL
      | None -> raise (Unparsable (sprintf "bad reason in packet_in (%d)" reason_code)) in
    let table_id = get_ofp_packet_in_table_id bits in
    let cookie = get_ofp_packet_in_cookie bits in
    let ofp_match_bits = Cstruct.shift bits sizeof_ofp_packet_in in
    let ofp_match, pkt_bits = OfpMatch.parse ofp_match_bits in
    let pkt_bits = Cstruct.sub pkt_bits 2 total_len in (* pad bytes *)
    let final_bits = Cstruct.create total_len in
    (* create a new Cstruct to set the offset to 0 *)
    Cstruct.blit pkt_bits 0 final_bits 0 total_len;
    (* printf "len = %d\n" (Cstruct.len pkt_bits); *)
    let pkt = match bufId with
      | None -> NotBuffered final_bits
      | Some n -> Buffered (n,final_bits)
    in
    { pi_total_len = total_len;
      pi_reason = reason;
      pi_table_id = table_id;
      pi_cookie = cookie;
      pi_ofp_match = ofp_match;
      pi_payload = pkt
    }
    
end

module PacketOut = struct

  cstruct ofp_packet_out {
      uint32_t buffer_id;           (* ID assigned by datapath (OFP_NO_BUFFER
                                       if none). *)
      uint32_t in_port;             (* Packet's input port or OFPP_CONTROLLER. *)
      uint16_t actions_len;         (* Size of action array in bytes. *)
      uint8_t pad0;
      uint8_t pad1;
      uint8_t pad2;
      uint8_t pad3;
      uint8_t pad4;
      uint8_t pad5
      (* struct ofp_action_header actions[0]; *) (* Action list. *)
      (* uint8_t data[0]; *)        (* Packet data.  The length is inferred
                                       from the length field in the header.
                                       (Only meaningful if buffer_id == -1.) *)
  } as big_endian

  let sizeof (po : packetOut) =
    sizeof_ofp_packet_out + sum (map Action.sizeof po.po_actions) +
    (match po.po_payload with
      | Buffered _ -> 0
      | NotBuffered bytes -> Cstruct.len bytes)

  let marshal (buf : Cstruct.t) (po : packetOut) : int =
    let size = sizeof po in
    set_ofp_packet_out_buffer_id buf (
      match po.po_payload with
        | NotBuffered _ -> 0xffffffffl
        | Buffered (buffer_id, _) -> buffer_id);
    set_ofp_packet_out_in_port buf
      (match po.po_port_id with
        | None -> 0l
        | Some(port_id) -> port_id);
    set_ofp_packet_out_actions_len buf (sum (map Action.sizeof po.po_actions));
    set_ofp_packet_out_pad0 buf 0;
    set_ofp_packet_out_pad1 buf 0;
    set_ofp_packet_out_pad2 buf 0;
    set_ofp_packet_out_pad3 buf 0;
    set_ofp_packet_out_pad4 buf 0;
    set_ofp_packet_out_pad5 buf 0;
    let buf = Cstruct.shift buf sizeof_ofp_packet_out in
    let act_size = marshal_fields buf po.po_actions Action.marshal in
    match po.po_payload with
      | Buffered _ -> size
      | NotBuffered pkt_buf ->
        Cstruct.blit pkt_buf 0 buf act_size (Cstruct.len pkt_buf);
        size

end

module FlowRequest = struct

    cstruct ofp_flow_stats_request {
      uint8_t table_id;
      uint8_t pad[3];
      uint32_t out_port;
      uint32_t out_group;
      uint8_t pad2[4];
      uint64_t cookie;
      uint64_t cookie_mask;
    } as big_endian

    let sizeof (fr : flowRequest) : int = 
    sizeof_ofp_flow_stats_request + (OfpMatch.sizeof fr.fr_match)

    let to_string (fr : flowRequest) : string =
      Format.sprintf "TableID:%u\noutPort:%lu\noutGroup:%lu\ncookie:%s\nmatch:%s"
      fr.fr_table_id
      fr.fr_out_port
      fr.fr_out_group
      (match fr.fr_cookie.m_mask with
        | None -> Int64.to_string fr.fr_cookie.m_value
        | Some m -> Format.sprintf "%Lu/%Lu" fr.fr_cookie.m_value m)
      (OfpMatch.to_string fr.fr_match)
  
    let marshal (buf : Cstruct.t) (fr : flowRequest) : int = 
      set_ofp_flow_stats_request_table_id buf fr.fr_table_id;
      set_ofp_flow_stats_request_out_port buf fr.fr_out_port;
      set_ofp_flow_stats_request_out_group buf fr.fr_out_group;
      set_ofp_flow_stats_request_cookie buf fr.fr_cookie.m_value;
      set_ofp_flow_stats_request_cookie_mask buf (
        match fr.fr_cookie.m_mask with
          | None -> 0L
          | Some mask -> mask);
      sizeof_ofp_flow_stats_request + (OfpMatch.marshal 
       (Cstruct.shift buf sizeof_ofp_flow_stats_request) fr.fr_match)
    
    
    let parse (bits : Cstruct.t) : flowRequest =
      let tableId = get_ofp_flow_stats_request_table_id bits in
      let out_port = get_ofp_flow_stats_request_out_port bits in
      let out_group = get_ofp_flow_stats_request_out_group bits in
      let cookie = get_ofp_flow_stats_request_cookie bits in
      let mask = get_ofp_flow_stats_request_cookie_mask bits in
      let fr_cookie = match mask with
                        | 0L -> {m_value = cookie; m_mask = None}
                        | n -> {m_value = cookie; m_mask = Some n} in
      let oxmMatch,_ = OfpMatch.parse (Cstruct.shift bits sizeof_ofp_flow_stats_request) in
      { fr_table_id = tableId
      ; fr_out_port = out_port
      ; fr_out_group = out_group
      ; fr_cookie = fr_cookie
      ; fr_match = oxmMatch}

end

module QueueRequest = struct

    let marshal (buf : Cstruct.t) (qr : queueRequest) : int =
      set_ofp_queue_stats_request_port_no buf qr.port_number;
      set_ofp_queue_stats_request_queue_id buf qr.queue_id;
      sizeof_ofp_queue_stats_request

    let parse (bits : Cstruct.t) : queueRequest = 
      let portNumber = get_ofp_queue_stats_request_port_no bits in
      let queueId = get_ofp_queue_stats_request_queue_id bits in
      { port_number = portNumber
      ; queue_id = queueId}

    let sizeof _ = 
        sizeof_ofp_queue_stats_request
    let to_string qr =
        Format.sprintf "Port:%lu;Queue:%lu" qr.port_number qr.queue_id
end

module TableFeatureProp = struct

    cstruct ofp_table_feature_prop_experimenter {
        uint16_t typ;
        uint16_t length;
        uint32_t experimenter;
        uint32_t exp_typ
    } as big_endian

    let sizeof tfp : int = 
      let size = sizeof_ofp_table_feature_prop_header + (match tfp with
        | TfpInstruction ins -> 
            Instructions.sizeof ins
        | TfpInstructionMiss ins -> 
            Instructions.sizeof ins
        | TfpNextTable t -> 
            List.length t
        | TfpNextTableMiss t -> 
            List.length t
        | TfpWriteAction act -> 
            sum (map Action.sizeof act)
        | TfpWriteActionMiss act -> 
            sum (map Action.sizeof act)
        | TfpApplyAction act -> 
            sum (map Action.sizeof act)
        | TfpApplyActionMiss act -> 
            sum (map Action.sizeof act)
        | TfpMatch ox -> 
            Oxm.sizeof_header ox
        | TfpWildcard ox -> 
            Oxm.sizeof_header ox
        | TfpWriteSetField ox-> 
            Oxm.sizeof_header ox
        | TfpWriteSetFieldMiss ox -> 
            Oxm.sizeof_header ox
        | TfpApplySetField ox -> 
            Oxm.sizeof_header ox
        | TfpApplySetFieldMiss ox -> 
            Oxm.sizeof_header ox
        | TfpExperimenter (_,by) -> 
            Cstruct.len by
        | TfpExperimenterMiss (_,by) -> 
            Cstruct.len by
            ) in
      pad_to_64bits size

    let marshal (buf : Cstruct.t) (tfp : tableFeatureProp) =
    let buf_payload = Cstruct.shift buf sizeof_ofp_table_feature_prop_header in
    let size = sizeof_ofp_table_feature_prop_header + (match tfp with
      | TfpInstruction ins -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_INSTRUCTIONS);
          Instructions.marshal buf_payload ins
      | TfpInstructionMiss ins -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_INSTRUCTIONS_MISS);
          Instructions.marshal buf_payload ins
      | TfpNextTable t -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_NEXT_TABLES);
          let marsh (buf : Cstruct.t) (id : uint8) : int =
            set_uint8 buf 0 id;
            1 in
          marshal_fields buf_payload t marsh
      | TfpNextTableMiss t -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_NEXT_TABLES_MISS);
          let marsh (buf : Cstruct.t) (id : uint8) : int =
            set_uint8 buf 0 id;
            1 in
          marshal_fields buf_payload t marsh
      | TfpWriteAction act -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_WRITE_ACTIONS);
          marshal_fields buf_payload act Action.marshal
      | TfpWriteActionMiss act -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_WRITE_ACTIONS_MISS);
          marshal_fields buf_payload act Action.marshal
      | TfpApplyAction act -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_APPLY_ACTIONS);
          marshal_fields buf_payload act Action.marshal
      | TfpApplyActionMiss act -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_APPLY_ACTIONS_MISS);
          marshal_fields buf_payload act Action.marshal
      | TfpMatch ox -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_MATCH);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpWildcard ox -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_WILDCARDS);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpWriteSetField ox-> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_WRITE_SETFIELD);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpWriteSetFieldMiss ox -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_WRITE_SETFIELD_MISS);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpApplySetField ox -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_APPLY_SETFIELD);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpApplySetFieldMiss ox -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_APPLY_SETFIELD_MISS);
          marshal_fields buf_payload ox Oxm.marshal_header
      | TfpExperimenter (ex,by) -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_EXPERIMENTER);
          Cstruct.blit by 0 buf_payload 0 (Cstruct.len by);
          Cstruct.len by
      | TfpExperimenterMiss (ex,by) -> 
          set_ofp_table_feature_prop_header_typ buf (ofp_table_feature_prop_type_to_int OFPTFPT_EXPERIMENTER_MISS);
          Cstruct.blit by 0 buf_payload 0 (Cstruct.len by);
          Cstruct.len by
          ) in
    set_ofp_table_feature_prop_header_length buf size;
    pad_to_64bits size

    let rec parse_tables (bits : Cstruct.t) len = 
        if Cstruct.len bits < 1 then ([], bits)
        else let field, bits2 = get_uint8 bits 0, Cstruct.shift bits 1 in
          let fields, bits3 = parse_tables bits2 (len -1) in
          (List.append [field] fields, bits3)

    let parse (bits : Cstruct.t) : tableFeatureProp =
     let tfpType = get_ofp_table_feature_prop_header_typ bits in
     let tfpLength = get_ofp_table_feature_prop_header_length bits in
     let tfpPayBits = Cstruct.sub bits sizeof_ofp_table_feature_prop_header (tfpLength - sizeof_ofp_table_feature_prop_header) in
     match int_to_ofp_table_feature_prop_type tfpType with
      | Some OFPTFPT_INSTRUCTIONS -> 
          TfpInstruction (Instructions.parse tfpPayBits)
      | Some OFPTFPT_INSTRUCTIONS_MISS -> 
          TfpInstructionMiss (Instructions.parse tfpPayBits)
      | Some OFPTFPT_NEXT_TABLES -> 
      let ids,_ = parse_tables tfpPayBits (tfpLength - sizeof_ofp_table_feature_prop_header) in
          TfpNextTable ids
      | Some OFPTFPT_NEXT_TABLES_MISS ->
          let ids,_ = parse_tables tfpPayBits (tfpLength - sizeof_ofp_table_feature_prop_header) in
          TfpNextTableMiss ids
      | Some OFPTFPT_WRITE_ACTIONS -> 
          TfpWriteAction (Action.parse_sequence tfpPayBits)
      | Some OFPTFPT_WRITE_ACTIONS_MISS -> 
          TfpWriteActionMiss (Action.parse_sequence tfpPayBits)
      | Some OFPTFPT_APPLY_ACTIONS -> 
          TfpApplyAction (Action.parse_sequence tfpPayBits)
      | Some OFPTFPT_APPLY_ACTIONS_MISS -> 
          TfpApplyActionMiss (Action.parse_sequence tfpPayBits)
      | Some OFPTFPT_MATCH -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpMatch fields
      | Some OFPTFPT_WILDCARDS -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpWildcard fields
      | Some OFPTFPT_WRITE_SETFIELD -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpWriteSetField fields
      | Some OFPTFPT_WRITE_SETFIELD_MISS -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpWriteSetFieldMiss fields
      | Some OFPTFPT_APPLY_SETFIELD -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpApplySetField fields
      | Some OFPTFPT_APPLY_SETFIELD_MISS -> 
          let fields,_ = Oxm.parse_headers tfpPayBits in 
          TfpApplySetFieldMiss fields
      | Some OFPTFPT_EXPERIMENTER -> 
          let exp_id = get_ofp_table_feature_prop_experimenter_experimenter bits in
          let exp_type = get_ofp_table_feature_prop_experimenter_exp_typ bits in
          TfpExperimenter ({exp_id;exp_type},tfpPayBits)
      | Some OFPTFPT_EXPERIMENTER_MISS -> 
          let exp_id = get_ofp_table_feature_prop_experimenter_experimenter bits in
          let exp_type = get_ofp_table_feature_prop_experimenter_exp_typ bits in
          TfpExperimenterMiss ({exp_id;exp_type},tfpPayBits)
      | _ -> raise (Unparsable (sprintf "malformed type"))

    let to_string tfp =
      Format.sprintf "type:%s;len:%u"
      (match tfp with
         | TfpInstruction i-> 
            (Format.sprintf "Instructions : %s" (Instructions.to_string i))
         | TfpInstructionMiss i-> 
            (Format.sprintf "InstructionMiss : %s" (Instructions.to_string i))
         | TfpNextTable n-> 
            (Format.sprintf "NextTable : %s" 
            (String.concat " " (map string_of_int n)))
         | TfpNextTableMiss n -> 
            (Format.sprintf "NextTableMiss : %s" 
            (String.concat " " (map string_of_int n)))
         | TfpWriteAction a -> 
            (Format.sprintf "WriteAction: \n%s"
            (String.concat "\n" (map Action.to_string a)))
         | TfpWriteActionMiss a -> 
            (Format.sprintf "WriteActionMiss: \n%s"
            (String.concat "\n" (map Action.to_string a)))
         | TfpApplyAction a -> 
            (Format.sprintf "ApplyActions: \n%s"
            (String.concat "\n" (map Action.to_string a)))
         | TfpApplyActionMiss a -> 
            (Format.sprintf "ApplyActionsMiss: \n%s"
            (String.concat "\n" (map Action.to_string a)))
         | TfpMatch s -> 
            (Format.sprintf "Match : \n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpWildcard s -> 
            (Format.sprintf "MatchMiss :\n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpWriteSetField s -> 
            (Format.sprintf "WriteSetField :\n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpWriteSetFieldMiss s -> 
            (Format.sprintf "WriteSetFieldMiss :\n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpApplySetField s -> 
            (Format.sprintf "ApplySetField :\n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpApplySetFieldMiss s -> 
            (Format.sprintf "ApplySetFieldMiss :\n%s"
            (String.concat "\n" (map Oxm.field_name s)))
         | TfpExperimenter (e,_)-> 
            (Format.sprintf "Experimenter:id:%lu;typ:%lu" e.exp_id e.exp_type)
         | TfpExperimenterMiss (e,_)-> 
            (Format.sprintf "ExperimenterMiss:id:%lu;typ:%lu" e.exp_id e.exp_type)
           )
      (sizeof tfp)

end

module TableFeature = struct

    let sizeof (tf : tableFeatures) =
      (* should be equal to tf.length *)
      pad_to_64bits (sizeof_ofp_table_features + (TableFeatureProp.sizeof tf.feature_prop))

    let tableConfig_to_int (tc : tableConfig) : int32 =
      match tc with
        | Deprecated -> ofp_table_config_to_int OFPTC_DEPRECATED_MASK

    let table_config_to_string tc =
      match tc with
        | Deprecated -> "Deprecated"

    let marshal (buf : Cstruct.t) (tf : tableFeatures) : int =
      set_ofp_table_features_length buf tf.length;
      set_ofp_table_features_table_id buf tf.table_id;
      set_ofp_table_features_pad (Cstruct.to_string (Cstruct.create 5)) 0 buf;
      set_ofp_table_features_name tf.name 0 buf;
      set_ofp_table_features_metadata_match buf tf.metadata_match;
      set_ofp_table_features_metadata_write buf tf.metadata_write;
      set_ofp_table_features_config buf (tableConfig_to_int tf.config);
      set_ofp_table_features_max_entries buf tf.max_entries;
      sizeof_ofp_table_features + (
        TableFeatureProp.marshal (Cstruct.shift buf sizeof_ofp_table_features) tf.feature_prop)

    let parse (bits : Cstruct.t) : tableFeatures*Cstruct.t = 
      let length = get_ofp_table_features_length bits in
      let tableId = get_ofp_table_features_table_id bits in
      let name = Cstruct.to_string (get_ofp_table_features_name bits) in
      let metadataMatch = get_ofp_table_features_metadata_match bits in
      let metadataWrite = get_ofp_table_features_metadata_write bits in
      let config = (
        match int_to_ofp_table_config (get_ofp_table_features_config bits) with
          | Some OFPTC_DEPRECATED_MASK -> Deprecated
          | _ -> raise
            (Unparsable (sprintf "unsupported config "))
        ) in
      let maxEntries = get_ofp_table_features_max_entries bits in
      let featureProp = TableFeatureProp.parse (Cstruct.sub bits sizeof_ofp_table_features (length-sizeof_ofp_table_features)) in
      { length = length;
        table_id = tableId;
        name = name;
        metadata_match = metadataMatch; 
        metadata_write = metadataWrite;
        config = config; 
        max_entries = maxEntries;
        feature_prop = featureProp},(Cstruct.shift bits length)
    
    let to_string (tf : tableFeatures) =
      Format.sprintf "tableId:%u;name:%s;metadata match:%Lu;\
                      metadata write:%Lu;config%s;max_entries:%lu;
                      featuresPro:%s"
      tf.table_id
      tf.name
      tf.metadata_match
      tf.metadata_write
      (table_config_to_string tf.config)
      tf.max_entries
      (TableFeatureProp.to_string tf.feature_prop)

end

module TableFeaturesRequest = struct

    let sizeof (tfr : tableFeaturesRequest) =
        sum (map TableFeature.sizeof tfr)

    let marshal (buf : Cstruct.t) (tfr : tableFeaturesRequest) =
      marshal_fields buf tfr TableFeature.marshal
      

    let rec parse_fields (bits : Cstruct.t) len cumul : tableFeaturesRequest*Cstruct.t = 
      if len = cumul then [],bits
      else (
        let field,nextBits = TableFeature.parse bits in
        let fields,bits3 = parse_fields nextBits len (cumul + (TableFeature.sizeof field)) in
        (List.append [field] fields,bits3)
      )    

    let parse (bits : Cstruct.t) : tableFeaturesRequest = 
      let length = Cstruct.len bits in
      let body,_ = parse_fields bits length 0 in
      body

    let to_string tfr = 
      let tfrString = String.concat "\n" (map TableFeature.to_string tfr) in
      tfrString
end

module MultipartReq = struct

    cstruct ofp_multipart_request {
      uint16_t typ; (* One of the OFPMP_* constants. *)
      uint16_t flags; (* OFPMPF_REQ_* flags. *)
      uint8_t pad0;
      uint8_t pad1;
      uint8_t pad2;
      uint8_t pad3
    } as big_endian

    cstruct ofp_experimenter_multipart_header {
      uint32_t experimenter;
      uint32_t exp_type
    } as big_endian

  let msg_code_of_request mpr = match mpr with
    | SwitchDescReq -> OFPMP_DESC
    | PortsDescReq -> OFPMP_PORT_DESC
    | FlowStatsReq _ -> OFPMP_FLOW
    | AggregFlowStatsReq _ -> OFPMP_AGGREGATE
    | TableStatsReq -> OFPMP_TABLE
    | PortStatsReq _ -> OFPMP_PORT_STATS
    | QueueStatsReq _ -> OFPMP_QUEUE
    | GroupStatsReq _ -> OFPMP_GROUP
    | GroupDescReq -> OFPMP_GROUP_DESC
    | GroupFeatReq -> OFPMP_GROUP_FEATURES
    | MeterStatsReq _ -> OFPMP_METER
    | MeterConfReq _ -> OFPMP_METER_CONFIG
    | MeterFeatReq -> OFPMP_METER_FEATURES
    | TableFeatReq _ -> OFPMP_TABLE_FEATURES
    | ExperimentReq _ -> OFPMP_EXPERIMENTER

  let sizeof (mpr : multipartRequest) =
    sizeof_ofp_multipart_request + 
    (match mpr.mpr_type with 
       | SwitchDescReq | PortsDescReq | TableStatsReq | MeterFeatReq | GroupDescReq
       | GroupFeatReq -> 0
       | FlowStatsReq fr -> FlowRequest.sizeof fr 
       | AggregFlowStatsReq fr -> FlowRequest.sizeof fr
       | PortStatsReq _ -> sizeof_ofp_port_stats_request 
       | QueueStatsReq _ -> sizeof_ofp_queue_stats_request
       | GroupStatsReq _ -> sizeof_ofp_group_stats_request 
       | MeterStatsReq _  | MeterConfReq _ -> sizeof_ofp_meter_multipart_request
       | TableFeatReq tfr -> (match tfr with
          | None -> 0
          | Some t -> TableFeaturesRequest.sizeof t)
       | ExperimentReq _ -> sizeof_ofp_experimenter_multipart_header)

  let to_string (mpr : multipartRequest) : string =
    Format.sprintf "more:%B;typ:%s"
    mpr.mpr_flags
    (match mpr.mpr_type with
      | SwitchDescReq -> "SwitchDesc Req"
      | PortsDescReq -> "PortDesc Req"
      | FlowStatsReq f -> 
          Format.sprintf "FlowStats %s Req" (FlowRequest.to_string f)
      | AggregFlowStatsReq f -> 
          Format.sprintf "AggregFlowStats %s Req" (FlowRequest.to_string f)
      | TableStatsReq -> "TableStats Req"
      | PortStatsReq p -> 
          Format.sprintf "PortStats %lu Req" p
      | QueueStatsReq q -> 
          Format.sprintf "QueueStats Req: %s" (QueueRequest.to_string q)
      | GroupStatsReq g -> Format.sprintf "GroupStats %lu Req" g
      | GroupDescReq -> "GroupDesc Req"
      | GroupFeatReq -> "GroupFeat Req"
      | MeterStatsReq m -> Format.sprintf "MeterStats Req: %lu " m
      | MeterConfReq m -> Format.sprintf "MeterConf Req: %lu" m
      | MeterFeatReq -> "MeterFeat Req"
      | TableFeatReq t-> Format.sprintf "TableFeat Req: %s" (match t with
        | Some v -> TableFeaturesRequest.to_string v
        | None -> "None" )
      | ExperimentReq e-> Format.sprintf "Experimenter Req: id: %lu; type: %lu" e.exp_id e.exp_type)

  let marshal (buf : Cstruct.t) (mpr : multipartRequest) : int =
    let size = sizeof_ofp_multipart_request in
    set_ofp_multipart_request_typ buf (ofp_multipart_types_to_int (msg_code_of_request mpr.mpr_type));
    set_ofp_multipart_request_flags buf (
      match mpr.mpr_flags with
        | true -> ofp_multipart_request_flags_to_int OFPMPF_REQ_MORE
        | false -> 0);
    set_ofp_multipart_request_pad0 buf 0;
    set_ofp_multipart_request_pad1 buf 0;
    set_ofp_multipart_request_pad2 buf 0;
    set_ofp_multipart_request_pad3 buf 0;
    let pay_buf = Cstruct.shift buf sizeof_ofp_multipart_request in
    match mpr.mpr_type with
      | SwitchDescReq
      | PortsDescReq -> size
      | FlowStatsReq f -> size + (FlowRequest.marshal pay_buf f)
      | AggregFlowStatsReq f -> size + (FlowRequest.marshal pay_buf f)
      | TableStatsReq -> size
      | PortStatsReq p -> set_ofp_port_stats_request_port_no pay_buf p;
                          size + sizeof_ofp_port_stats_request
      | QueueStatsReq q -> size + (QueueRequest.marshal pay_buf q)
      | GroupStatsReq g -> set_ofp_port_stats_request_port_no pay_buf g;
                           size + sizeof_ofp_port_stats_request
      | GroupDescReq
      | GroupFeatReq -> size
      | MeterStatsReq m -> set_ofp_meter_multipart_request_meter_id pay_buf m;
                           size + sizeof_ofp_meter_multipart_request
      | MeterConfReq m -> set_ofp_meter_multipart_request_meter_id pay_buf m;
                          size + sizeof_ofp_meter_multipart_request
      | MeterFeatReq -> size
      | TableFeatReq t -> 
        (match t with
          | None -> 0
          | Some v -> size + (TableFeaturesRequest.marshal pay_buf v))
      | ExperimentReq _ -> size

  let parse (bits : Cstruct.t) : multipartRequest =
    let mprType = int_to_ofp_multipart_types (get_ofp_multipart_request_typ bits) in
    let mpr_flags = (
      match int_to_ofp_multipart_request_flags (get_ofp_multipart_request_flags bits) with
        | Some OFPMPF_REQ_MORE -> true
        | _ -> false) in
    let mpr_type = match mprType with
      | Some OFPMP_DESC -> SwitchDescReq
      | Some OFPMP_PORT_DESC -> PortsDescReq
      | Some OFPMP_FLOW -> FlowStatsReq (
        FlowRequest.parse (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_AGGREGATE -> AggregFlowStatsReq (
        FlowRequest.parse (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_TABLE -> TableStatsReq
      | Some OFPMP_PORT_STATS -> PortStatsReq (
        get_ofp_port_stats_request_port_no (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_QUEUE -> QueueStatsReq (
        QueueRequest.parse (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_GROUP -> GroupStatsReq (
        get_ofp_group_stats_request_group_id (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_GROUP_DESC -> GroupDescReq
      | Some OFPMP_GROUP_FEATURES -> GroupFeatReq
      | Some OFPMP_METER -> MeterStatsReq (
        get_ofp_meter_multipart_request_meter_id (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_METER_CONFIG -> MeterConfReq (
        get_ofp_meter_multipart_request_meter_id (Cstruct.shift bits sizeof_ofp_multipart_request))
      | Some OFPMP_METER_FEATURES -> MeterFeatReq
      | Some OFPMP_TABLE_FEATURES -> TableFeatReq (
      if Cstruct.len bits <= sizeof_ofp_multipart_request then None
      else Some (
        TableFeaturesRequest.parse (Cstruct.shift bits sizeof_ofp_multipart_request)
      ))
      | Some OFPMP_EXPERIMENTER -> ExperimentReq (
      let exp_bits = Cstruct.shift bits sizeof_ofp_multipart_request in
      let exp_id = get_ofp_experimenter_multipart_header_experimenter exp_bits in
      let exp_type = get_ofp_experimenter_multipart_header_exp_type exp_bits in
      {exp_id; exp_type})
      | _ -> raise (Unparsable (sprintf "bad ofp_multipart_types number"))
    in {mpr_type; mpr_flags}


end

module PortsDescriptionReply = struct

  let sizeof (pd : portDesc list) = 
    sum (map PortDesc.sizeof pd)

  let to_string pd = 
   String.concat "\n" (map PortDesc.to_string pd) 

  let marshal (buf : Cstruct.t) (sdr : portDesc list) : int =
    let rec marshalPort (sdrl : portDesc list) off: int = 
      match sdrl with
        | [] -> 0
        | t::q -> PortDesc.marshal (Cstruct.shift buf off) t +
                  marshalPort q (off + sizeof_ofp_port) in
    marshalPort sdr 0

  let parse (bits : Cstruct.t) : portDesc list =
    let portIter =
      Cstruct.iter
        (fun buf -> Some sizeof_ofp_port)
        PortDesc.parse
        bits in
    List.rev (Cstruct.fold (fun acc bits -> bits :: acc) portIter [])

end

module SwitchDescriptionReply = struct

  let sizeof (sdr : switchDesc) : int = 
    sizeof_ofp_desc
  
  let to_string (sdr : switchDesc) : string =
    Format.sprintf "Manufacture desc: %s\nHardware desc: %s\nSoftware desc: %s\nSerial Num:%s\n"
    sdr.mfr_desc
    sdr.hw_desc
    sdr.sw_desc
    sdr.serial_num

  let marshal (buf : Cstruct.t) (sdr : switchDesc) : int =
    set_ofp_desc_mfr_desc sdr.mfr_desc 0 buf;
    set_ofp_desc_hw_desc sdr.hw_desc 0 buf;
    set_ofp_desc_sw_desc sdr.sw_desc 0 buf;
    set_ofp_desc_serial_num sdr.serial_num 0 buf;
    sizeof_ofp_desc

  let parse (bits : Cstruct.t) : switchDesc = 
    let mfr_desc = copy_ofp_desc_mfr_desc bits in
    let hw_desc = copy_ofp_desc_hw_desc bits in
    let sw_desc = copy_ofp_desc_sw_desc bits in
    let serial_num = copy_ofp_desc_serial_num bits in
    { mfr_desc;
      hw_desc;
      sw_desc;
      serial_num}

end

cstruct ofp_flow_stats {
  uint16_t length;
  uint8_t table_id;
  uint8_t pad0;
  uint32_t duration_sec;
  uint32_t duration_nsec;
  uint16_t priority;
  uint16_t idle_timeout;
  uint16_t hard_timeout;
  uint16_t flags;
  uint8_t pad1[4];
  uint64_t cookie;
  uint64_t packet_count;
  uint64_t byte_count;
} as big_endian

module Flow = struct
  
  let sizeof_struct (fs : flowStats) = 
    sizeof_ofp_flow_stats + 
    (OfpMatch.sizeof fs.ofp_match)+
    (Instructions.sizeof fs.instructions)
  
  let sizeof (fs : flowStats list) = 
    sum (map sizeof_struct fs)
  
  let to_string_struct f =
    Format.sprintf "length:%u;\ntableId:%u;\nduration:%lus:%luns\npriority:%u\n\
    idle_timeout:%s;\nhard_timeout:%s;\nflags:%s;\ncookie:%Lu\npkt_count:%Lu\n\
    byt_count:%Lu;\nmatch:%s;\ninstructions:%s\n"
    (sizeof_struct f)
    f.table_id
    f.duration_sec
    f.duration_nsec
    f.priority
    (match f.idle_timeout with
       | Permanent -> "Permanent"
       | ExpiresAfter v -> string_of_int v)
    (match f.hard_timeout with
       | Permanent -> "Permanent"
       | ExpiresAfter v -> string_of_int v)
    (Format.sprintf 
    "send_flow_rem:%B\ncheck_overlap:%B\nreset_count:%B\nno_pkt_count:%B\n\
    no_byt_count:%B"
    f.flags.fmf_send_flow_rem 
    f.flags.fmf_check_overlap 
    f.flags.fmf_reset_counts 
    f.flags.fmf_no_pkt_counts 
    f.flags.fmf_no_byt_counts 
    )
    f.cookie
    f.packet_count
    f.byte_count
    (OfpMatch.to_string f.ofp_match)
    (Instructions.to_string f.instructions)

  let to_string (f : flowStats list) = 
   String.concat "\n" (map to_string_struct f)   

  let flags_to_int (f : flowModFlags) =
  (if f.fmf_send_flow_rem then 1 lsl 0 else 0) lor
    (if f.fmf_check_overlap then 1 lsl 1 else 0) lor
      (if f.fmf_reset_counts then 1 lsl 2 else 0) lor
        (if f.fmf_no_pkt_counts then 1 lsl 3 else 0) lor
          (if f.fmf_no_byt_counts then 1 lsl 4 else 0) 

  let int_to_flags i : flowModFlags =
   { fmf_send_flow_rem = test_bit16 0 i
   ; fmf_check_overlap = test_bit16 1 i
   ; fmf_reset_counts = test_bit16 2 i
   ; fmf_no_pkt_counts = test_bit16 3 i
   ; fmf_no_byt_counts = test_bit16 4 i}

  let marshal_struct (buf : Cstruct.t) (fs : flowStats) : int =
    set_ofp_flow_stats_length buf (sizeof_struct fs);
    set_ofp_flow_stats_table_id buf fs.table_id;
    set_ofp_flow_stats_pad0 buf 0;
    set_ofp_flow_stats_duration_sec buf fs.duration_sec;
    set_ofp_flow_stats_duration_nsec buf fs.duration_nsec;
    set_ofp_flow_stats_priority buf fs.priority;
    set_ofp_flow_stats_idle_timeout buf 
      (match fs.idle_timeout with
         | Permanent -> 0
         | ExpiresAfter  v -> v);
    set_ofp_flow_stats_hard_timeout buf 
      (match fs.hard_timeout with
         | Permanent -> 0
         | ExpiresAfter  v -> v);     
    set_ofp_flow_stats_flags buf (flags_to_int fs.flags);
    set_ofp_flow_stats_pad1 (Cstruct.to_string (Cstruct.create 4)) 0 buf;
    set_ofp_flow_stats_cookie buf fs.cookie;
    set_ofp_flow_stats_packet_count buf fs.packet_count;
    set_ofp_flow_stats_byte_count buf fs.byte_count;
    let size = sizeof_ofp_flow_stats + 
      OfpMatch.marshal (Cstruct.shift buf sizeof_ofp_flow_stats) fs.ofp_match in
     size + Instructions.marshal (Cstruct.shift buf size) fs.instructions

  let marshal (buf : Cstruct.t) (fs : flowStats list) : int =
    marshal_fields buf fs marshal_struct

  let parse_struct (bits : Cstruct.t) : flowStats =
    let table_id = get_ofp_flow_stats_table_id bits in
    let duration_sec = get_ofp_flow_stats_duration_sec bits in
    let duration_nsec = get_ofp_flow_stats_duration_nsec bits in
    let priority = get_ofp_flow_stats_priority bits in
    let idle_timeout = match (get_ofp_flow_stats_idle_timeout bits) with
                         | 0 -> Permanent 
                         | n -> ExpiresAfter n in
    let hard_timeout = match (get_ofp_flow_stats_hard_timeout bits) with
                         | 0 -> Permanent
                         | n -> ExpiresAfter n in
    let flagsBits = get_ofp_flow_stats_flags bits in
    let flags = int_to_flags flagsBits in
    let cookie = get_ofp_flow_stats_cookie bits in
    let packet_count = get_ofp_flow_stats_packet_count bits in
    let byte_count = get_ofp_flow_stats_byte_count bits in
    let ofp_match_bits = Cstruct.shift bits sizeof_ofp_flow_stats in
    let ofp_match, instruction_bits = OfpMatch.parse ofp_match_bits in
    let instructions = Instructions.parse instruction_bits in
    { table_id
    ; duration_sec
    ; duration_nsec
    ; priority
    ; idle_timeout
    ; hard_timeout
    ; flags
    ; cookie
    ; packet_count
    ; byte_count
    ; ofp_match
    ; instructions}

    let length_fn (buf :  Cstruct.t) : int option =
        if Cstruct.len buf < sizeof_ofp_flow_stats then None
        else Some (get_ofp_flow_stats_length buf)

    let parse (bits : Cstruct.t) : flowStats list =
    let flowIter =
      Cstruct.iter
        length_fn (* /*\ size if variable *)
        parse_struct
        bits in
    List.rev (Cstruct.fold (fun acc bits -> bits :: acc) flowIter [])

end

module Aggregate = struct
  
  cstruct ofp_aggregate_stats_reply {
    uint64_t packet_count;
    uint64_t byte_count;
    uint32_t flow_count;
    uint8_t pad[4];
  } as big_endian

  let sizeof ag = 
    sizeof_ofp_aggregate_stats_reply

  let to_string (ag : aggregStats) =
    Format.sprintf "packet count:%Lu;\nbyte count:%Lu;\nflow count:%lu\n"
    ag.packet_count
    ag.byte_count
    ag.flow_count

  let marshal (buf : Cstruct.t) (ag : aggregStats) : int =
    set_ofp_aggregate_stats_reply_packet_count buf ag.packet_count;
    set_ofp_aggregate_stats_reply_byte_count buf ag.byte_count;
    set_ofp_aggregate_stats_reply_flow_count buf ag.flow_count;
    set_ofp_aggregate_stats_reply_pad (Cstruct.to_string (Cstruct.create 4)) 0 buf;
    sizeof_ofp_aggregate_stats_reply

  let parse (bits : Cstruct.t) : aggregStats =
    { packet_count = (get_ofp_aggregate_stats_reply_packet_count bits)
    ; byte_count = (get_ofp_aggregate_stats_reply_byte_count bits)
    ; flow_count = (get_ofp_aggregate_stats_reply_flow_count bits)}

end

module Table = struct
  cstruct ofp_table_stats {
    uint8_t table_id; 
    uint8_t pad[3]; 
    uint32_t active_count;
    uint64_t lookup_count;
    uint64_t matched_count;
  } as big_endian

  let sizeof_struct (ts : tableStats) = 
    sizeof_ofp_table_stats
  
  let sizeof (ts : tableStats list) = 
    sum (map sizeof_struct ts)

  let to_string_struct (ts : tableStats) =
    Format.sprintf "table id: %u;\nactive count: %lu;\nlookup count: %Lu;\n\
    matched count : %Lu;\n"
    ts.table_id
    ts.active_count
    ts.lookup_count
    ts.matched_count
    
  let to_string (t : tableStats list) = 
   String.concat "\n" (map to_string_struct t) 

  let marshal_struct (buf : Cstruct.t) (ts : tableStats) : int =
    set_ofp_table_stats_table_id buf ts.table_id;
    set_ofp_table_stats_pad (Cstruct.to_string (Cstruct.create 3)) 0 buf;
    set_ofp_table_stats_active_count buf ts.active_count;
    set_ofp_table_stats_lookup_count buf ts.lookup_count;
    set_ofp_table_stats_matched_count buf ts.matched_count;
    sizeof_ofp_table_stats
    
  let marshal (buf : Cstruct.t) (ts : tableStats list) : int = 
    marshal_fields buf ts marshal_struct

  let parse_struct (bits : Cstruct.t) : tableStats =
    { table_id = get_ofp_table_stats_table_id bits
    ; active_count = get_ofp_table_stats_active_count bits
    ; lookup_count = get_ofp_table_stats_lookup_count bits
    ; matched_count = get_ofp_table_stats_matched_count bits}

  let parse (bits : Cstruct.t) : tableStats list =
    let tableIter =
      Cstruct.iter
        (fun buf -> Some sizeof_ofp_table_stats)
        parse_struct
        bits in
    List.rev (Cstruct.fold (fun acc bits -> bits :: acc) tableIter [])
end

module PortStats = struct
  
  let sizeof_struct (ps : portStats) = 
    sizeof_ofp_port_stats
  
  let sizeof (ps : portStats list) = 
    sum (map sizeof_struct ps)

  let to_string_struct ps =
    Format.sprintf "PortNo: %lu\nrx/tx pkt: %Lu/%Lu\nrx/tx byt: %Lu/%Lu\n\
    rx/tx dropped : %Lu/%Lu\nrx/tx error: %Lu/%Lu\nrx frame error: %Lu\nrx over err: \n
    %Lu \nrx crc err: %Lu\ncollisisions: %Lu\nduration (s/ns): %lu/%lu"
    ps.psPort_no
    ps.rx_packets
    ps.tx_packets
    ps.rx_bytes
    ps.tx_bytes
    ps.rx_dropped
    ps.tx_dropped
    ps.rx_errors
    ps.tx_errors
    ps.rx_frame_err
    ps.rx_over_err
    ps.rx_crc_err
    ps.collisions
    ps.duration_sec
    ps.duration_nsec

  let to_string (t : portStats list) = 
   String.concat "\n" (map to_string_struct t) 

  let marshal_struct (buf : Cstruct.t) (ps : portStats) : int =
    set_ofp_port_stats_port_no buf ps.psPort_no;
    set_ofp_port_stats_pad (Cstruct.to_string (Cstruct.create 4)) 0 buf;
    set_ofp_port_stats_rx_packets buf ps.rx_packets;
    set_ofp_port_stats_tx_packets buf ps.tx_packets;
    set_ofp_port_stats_rx_bytes buf ps.rx_bytes;
    set_ofp_port_stats_tx_bytes buf ps.tx_bytes;
    set_ofp_port_stats_rx_dropped buf ps.rx_dropped;
    set_ofp_port_stats_tx_dropped buf ps.tx_dropped;
    set_ofp_port_stats_rx_errors buf ps.rx_errors;
    set_ofp_port_stats_tx_errors buf ps.tx_errors;
    set_ofp_port_stats_rx_frame_err buf ps.rx_frame_err;
    set_ofp_port_stats_rx_over_err buf ps.rx_over_err;
    set_ofp_port_stats_rx_crc_err buf ps.rx_crc_err;
    set_ofp_port_stats_collisions buf ps.collisions;
    set_ofp_port_stats_duration_sec buf ps.duration_sec;
    set_ofp_port_stats_duration_nsec buf ps.duration_nsec;
    sizeof_ofp_port_stats
    
  let marshal (buf : Cstruct.t) (ps : portStats list) : int = 
    marshal_fields buf ps marshal_struct

  let parse_struct (bits : Cstruct.t) : portStats =
    { psPort_no     = get_ofp_port_stats_port_no bits;
      rx_packets    = get_ofp_port_stats_rx_packets bits;
      tx_packets    = get_ofp_port_stats_tx_packets bits;
      rx_bytes      = get_ofp_port_stats_rx_bytes bits;
      tx_bytes      = get_ofp_port_stats_tx_bytes bits;
      rx_dropped    = get_ofp_port_stats_rx_dropped bits;
      tx_dropped    = get_ofp_port_stats_tx_dropped bits;
      rx_errors     = get_ofp_port_stats_rx_errors bits;
      tx_errors     = get_ofp_port_stats_tx_errors bits;
      rx_frame_err  = get_ofp_port_stats_rx_frame_err bits;
      rx_over_err   = get_ofp_port_stats_rx_over_err bits;
      rx_crc_err    = get_ofp_port_stats_rx_crc_err bits;
      collisions    = get_ofp_port_stats_collisions bits;
      duration_sec  = get_ofp_port_stats_duration_sec bits;
      duration_nsec = get_ofp_port_stats_duration_nsec bits
    }

  let parse (bits : Cstruct.t) : portStats list =
    let portIter =
      Cstruct.iter
        (fun buf -> Some sizeof_ofp_port_stats)
        parse_struct
        bits in
    List.rev (Cstruct.fold (fun acc bits -> bits :: acc) portIter [])
end

module QueueStats = struct

    cstruct ofp_queue_stats {
      uint32_t port_no;
      uint32_t queue_id;
      uint64_t tx_bytes;
      uint64_t tx_packets;
      uint64_t tx_errors;
      uint32_t duration_sec;
      uint32_t duration_nsec
    } as big_endian

    let sizeof_struct (qs : queueStats) : int =
      sizeof_ofp_queue_stats

    let sizeof (qs : queueStats list) : int =
      sum (map sizeof_struct qs)

    let to_string_struct (qs : queueStats) : string =
      Format.sprintf "Port no:%lu\nQueue ID:%lu\ntx bytes:%Lu\ntx pkt:%Lu\ntx errors:%Lu\nduration (s/ns):%lu/%lu"
      qs.qsPort_no
      qs.queue_id
      qs.tx_bytes
      qs.tx_packets
      qs.tx_errors
      qs.duration_sec
      qs.duration_nsec

    let to_string (t : queueStats list) =
      String.concat "\n" (map to_string_struct t)

    let marshal_struct (buf : Cstruct.t) (qs : queueStats) : int = 
      set_ofp_queue_stats_port_no buf qs.qsPort_no;
      set_ofp_queue_stats_queue_id buf qs.queue_id;
      set_ofp_queue_stats_tx_bytes buf qs.tx_bytes;
      set_ofp_queue_stats_tx_packets buf qs.tx_packets;
      set_ofp_queue_stats_tx_errors buf qs.tx_errors;
      set_ofp_queue_stats_duration_sec buf qs.duration_sec;
      set_ofp_queue_stats_duration_nsec buf qs.duration_nsec;
      sizeof_ofp_queue_stats

    let marshal (buf : Cstruct.t) (qs : queueStats list) : int =
      marshal_fields buf qs marshal_struct

    let parse_struct (bits : Cstruct.t) : queueStats =
      { qsPort_no = get_ofp_queue_stats_port_no bits
      ; queue_id = get_ofp_queue_stats_queue_id bits
      ; tx_bytes = get_ofp_queue_stats_tx_bytes bits
      ; tx_packets = get_ofp_queue_stats_tx_packets bits
      ; tx_errors = get_ofp_queue_stats_tx_errors bits
      ; duration_sec = get_ofp_queue_stats_duration_sec bits
      ; duration_nsec = get_ofp_queue_stats_duration_nsec bits
      }

    let parse (bits : Cstruct.t) : queueStats list= 
      let queueIter =
        Cstruct.iter
          (fun buf -> Some sizeof_ofp_queue_stats)
          parse_struct
          bits in
      List.rev (Cstruct.fold (fun acc bits -> bits :: acc) queueIter [])
end

module GroupStats = struct

  cstruct ofp_group_stats {
    uint16_t length;
    uint8_t pad[2];
    uint32_t group_id;
    uint32_t ref_count;
    uint8_t pad2[4];
    uint64_t packet_count;
    uint64_t byte_count;
    uint32_t duration_sec;
    uint32_t duration_nsec
  } as big_endian

  module BucketStats = struct

    cstruct ofp_bucket_counter {
    uint64_t packet_count;
    uint64_t byte_count
    } as big_endian

    let sizeof_struct (gs : bucketStats) : int =
      sizeof_ofp_bucket_counter

    let sizeof (gs : bucketStats list) = 
      sum (map sizeof_struct gs)    
    
    let to_string_struct (bs : bucketStats) : string =
      Format.sprintf "Bucket: packet_count: %Lu;byte_count: %Lu"
      bs.packet_count
      bs.byte_count

    let to_string (bs : bucketStats list) : string =
      String.concat "\n" (map to_string_struct bs)   
 
    let marshal_struct (buf : Cstruct.t) (bs : bucketStats) : int =
      set_ofp_bucket_counter_packet_count buf bs.packet_count;
      set_ofp_bucket_counter_byte_count buf bs.byte_count;
      sizeof_ofp_bucket_counter

    let marshal (buf : Cstruct.t) (bs : bucketStats list) : int =
      marshal_fields buf bs marshal_struct

    let parse_struct (bits : Cstruct.t) : bucketStats =
      { packet_count = get_ofp_bucket_counter_packet_count bits
      ; byte_count = get_ofp_bucket_counter_byte_count bits }

    let parse (bits : Cstruct.t) : bucketStats list =
      let bucketIter =
        Cstruct.iter 
          (fun buf -> Some sizeof_ofp_bucket_counter)
          parse_struct
          bits in
       List.rev (Cstruct.fold (fun acc bits -> bits :: acc) bucketIter [])
  end

  let sizeof_struct (gs : groupStats) : int =
    gs.length

  let sizeof (gs : groupStats list) = 
    sum (map sizeof_struct gs)

  let to_string_struct (gs : groupStats) : string =
    Format.sprintf "length: %u; group id: %lu; ref count: %lu; packet count: %Lu;\
    byte count: %Lu; duration (s/ns): %lu/%lu;bucket stats:%s"
    gs.length
    gs.group_id
    gs.ref_count
    gs.packet_count
    gs.byte_count
    gs.duration_sec
    gs.duration_nsec
    (BucketStats.to_string gs.bucket_stats)

  let to_string (gs : groupStats list) : string =
    String.concat "\n" (map to_string_struct gs)   

  let marshal_struct (buf : Cstruct.t) (gs : groupStats) : int = 
    set_ofp_group_stats_length buf gs.length;
    set_ofp_group_stats_group_id buf gs.group_id;
    set_ofp_group_stats_ref_count buf gs.ref_count;
    set_ofp_group_stats_packet_count buf gs.packet_count;
    set_ofp_group_stats_byte_count buf gs.byte_count;
    set_ofp_group_stats_duration_sec buf gs.duration_sec;
    set_ofp_group_stats_duration_nsec buf gs.duration_nsec;
    sizeof_ofp_group_stats + (BucketStats.marshal (Cstruct.shift buf sizeof_ofp_group_stats) gs.bucket_stats)
    
  let marshal (buf : Cstruct.t) (gs : groupStats list) : int =
    marshal_fields buf gs marshal_struct

  let parse_struct (bits : Cstruct.t) : groupStats =
    { length = get_ofp_group_stats_length bits
    ; group_id = get_ofp_group_stats_group_id bits
    ; ref_count = get_ofp_group_stats_ref_count bits
    ; packet_count = get_ofp_group_stats_packet_count bits
    ; byte_count = get_ofp_group_stats_byte_count bits
    ; duration_sec = get_ofp_group_stats_duration_sec bits
    ; duration_nsec = get_ofp_group_stats_duration_nsec bits
    ; bucket_stats = BucketStats.parse (Cstruct.shift bits sizeof_ofp_group_stats)
    }

  let length_fn (buf :  Cstruct.t) : int option =
        if Cstruct.len buf < sizeof_ofp_group_stats then None
        else Some (get_ofp_group_stats_length buf)

  let parse (bits : Cstruct.t) : groupStats list =
    let groupStatsIter =
      Cstruct.iter 
        length_fn
        parse_struct
        bits in
     List.rev (Cstruct.fold (fun acc bits -> bits :: acc) groupStatsIter [])
end

module MultipartReply = struct


  let sizeof (mpr : multipartReply) =
    sizeof_ofp_multipart_reply +
    match mpr.mpreply_typ with
      | PortsDescReply pdr -> PortsDescriptionReply.sizeof pdr
      | SwitchDescReply _ -> sizeof_ofp_desc
      | FlowStatsReply fsr -> Flow.sizeof fsr
      | AggregateReply ag -> Aggregate.sizeof ag
      | TableReply tr -> Table.sizeof tr
      | PortStatsReply psr -> PortStats.sizeof psr
      | QueueStatsReply qsr -> QueueStats.sizeof qsr
      | GroupStatsReply gs -> GroupStats.sizeof gs

  let to_string (mpr : multipartReply) =
    match mpr.mpreply_typ with
      | PortsDescReply pdr -> Format.sprintf "PortsDescReply: %s" (PortsDescriptionReply.to_string pdr)
      | SwitchDescReply sdc -> Format.sprintf "SwitchDescReply: %s" (SwitchDescriptionReply.to_string sdc)
      | FlowStatsReply fsr -> Format.sprintf "Flow: %s" (Flow.to_string fsr)
      | AggregateReply ag -> Format.sprintf "Aggregate Flow: %s" (Aggregate.to_string ag)
      | TableReply tr -> Format.sprintf "TableReply: %s" (Table.to_string tr)
      | PortStatsReply psr -> Format.sprintf "PortStatsReply: %s" (PortStats.to_string psr)
      | QueueStatsReply qsr -> Format.sprintf "QueueStats: %s" (QueueStats.to_string qsr)
      | GroupStatsReply gs -> Format.sprintf "GroupSTats: %S" (GroupStats.to_string gs)

  let marshal (buf : Cstruct.t) (mpr : multipartReply) : int =
    let ofp_body_bits = Cstruct.shift buf sizeof_ofp_multipart_reply in
    set_ofp_multipart_reply_flags buf (
      match mpr.mpreply_flags with
        | true -> ofp_multipart_request_flags_to_int OFPMPF_REQ_MORE
        | false -> 0);
    sizeof_ofp_multipart_reply + (match mpr.mpreply_typ with
      | PortsDescReply pdr -> 
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_PORT_DESC);
          PortsDescriptionReply.marshal ofp_body_bits pdr
      | SwitchDescReply sdr -> 
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_DESC);
          SwitchDescriptionReply.marshal ofp_body_bits sdr
      | FlowStatsReply fsr -> 
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_FLOW);
          Flow.marshal ofp_body_bits fsr
      | AggregateReply ar -> 
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_AGGREGATE);
          Aggregate.marshal ofp_body_bits ar
      | TableReply tr ->
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_TABLE);
          Table.marshal ofp_body_bits tr
      | PortStatsReply psr ->
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_PORT_STATS);
          PortStats.marshal ofp_body_bits psr
      | QueueStatsReply qsr ->
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_QUEUE);
          QueueStats.marshal ofp_body_bits qsr
      | GroupStatsReply gs ->
          set_ofp_multipart_reply_typ buf (ofp_multipart_types_to_int OFPMP_GROUP);
          GroupStats.marshal ofp_body_bits gs
          )
    
  let parse (bits : Cstruct.t) : multipartReply =
    let ofp_body_bits = Cstruct.shift bits sizeof_ofp_multipart_reply in
    let typ = (match int_to_ofp_multipart_types (get_ofp_multipart_reply_typ bits) with
      | Some OFPMP_PORT_DESC -> 
          PortsDescReply (PortsDescriptionReply.parse ofp_body_bits)
      | Some OFPMP_DESC -> 
          SwitchDescReply (SwitchDescriptionReply.parse ofp_body_bits)
      | Some OFPMP_FLOW -> 
          FlowStatsReply (Flow.parse ofp_body_bits)
      | Some OFPMP_AGGREGATE -> 
          AggregateReply (Aggregate.parse ofp_body_bits)
      | Some OFPMP_TABLE -> 
          TableReply (Table.parse ofp_body_bits)
      | Some OFPMP_PORT_STATS -> 
          PortStatsReply (PortStats.parse ofp_body_bits)
      | Some OFPMP_QUEUE ->
          QueueStatsReply (QueueStats.parse ofp_body_bits)
      | Some OFPMP_GROUP ->
          GroupStatsReply (GroupStats.parse ofp_body_bits)
      | _ -> raise (Unparsable (sprintf "NYI: can't parse this multipart reply"))) in
    let flags = (
      match int_to_ofp_multipart_request_flags (get_ofp_multipart_request_flags bits) with
        | Some OFPMPF_REQ_MORE -> true
        | _ -> false) in
    {mpreply_typ = typ; mpreply_flags = flags}

end

module TableMod = struct

    cstruct ofp_table_mod {
      uint8_t table_id;
      uint8_t pad[3];
      uint32_t confi
    } as big_endian
    

    let sizeof (tab : tableMod) : int =
    sizeof_ofp_table_mod

end


module Error = struct

  type t = {
    typ : int16;
    code : int16;
  }

  cstruct ofp_error_msg {
    uint16_t typ;
    uint16_t code
  } as big_endian
  
  (* page 95 of OF 1.3.1 *)
  let parse (bits : Cstruct.t) : t =
    let typ = get_ofp_error_msg_typ bits in
    let code = get_ofp_error_msg_code bits in
    { typ; code }

  let to_string (error : t) : string =
    Format.sprintf "error type=%d, code=%d" error.typ error.code

end

module Message = struct

  type t =
    | Hello
    | EchoRequest of bytes
    | EchoReply of bytes
    | FeaturesRequest
    | FeaturesReply of SwitchFeatures.t
    | FlowModMsg of flowMod
    | GroupModMsg of groupMod
    | PacketInMsg of packetIn
    | PacketOutMsg of packetOut
    | PortStatusMsg of portStatus
    | MultipartReq of multipartRequest
    | MultipartReply of multipartReply
    | BarrierRequest
    | BarrierReply
    | Error of Error.t


  let string_of_msg_code (msg : msg_code) : string = match msg with
    | HELLO -> "HELLO"
    | ECHO_REQ -> "ECHO_REQ"
    | ECHO_RESP -> "ECHO_RESP"
    | FEATURES_REQ -> "FEATURES_REQ"
    | FEATURES_RESP -> "FEATURES_RESP"
    | FLOW_MOD -> "FLOW_MOD"
    | GROUP_MOD -> "GROUP_MOD"
    | PACKET_IN -> "PACKET_IN"
    | PACKET_OUT -> "PACKET_OUT"
    | PORT_STATUS -> "PORT_STATUS"
    | MULTIPART_REQ -> "MULTIPART_REQ"
    | MULTIPART_RESP -> "MULTIPART_RESP"
    | BARRIER_REQ -> "BARRIER_REQ"
    | BARRIER_RESP -> "BARRIER_RESP"
    | ERROR -> "ERROR"
    | VENDOR -> "VENDOR"
    | GET_CONFIG_REQ -> "GET_CONFIG_REQ"
    | GET_CONFIG_RESP -> "GET_CONFIG_RESP"
    | SET_CONFIG -> "SET_CONFIG"
    | FLOW_REMOVED -> "FLOW_REMOVED"
    | PORT_MOD -> "PORT_MOD"
    | TABLE_MOD -> "TABLE_MOD"
    | QUEUE_GET_CONFIG_REQ -> "QUEUE_GET_CONFIG_REQ"
    | QUEUE_GET_CONFIG_RESP -> "QUEUE_GET_CONFIG_RESP"
    | ROLE_REQ -> "ROLE_REQ"
    | ROLE_RESP -> "ROLE_RESP"
    | GET_ASYNC_REQ -> "GET_ASYNC_REQ"
    | GET_ASYNC_REP -> "GET_ASYNC_REP"
    | SET_ASYNC -> "SEC_ASYNC"
    | METER_MOD -> "METER_MOD"

  module Header = OpenFlow_Header

  let msg_code_of_message (msg : t) : msg_code = match msg with
    | Hello -> HELLO
    | EchoRequest _ -> ECHO_REQ
    | EchoReply _ -> ECHO_RESP
    | FeaturesRequest -> FEATURES_REQ
    | FeaturesReply _ -> FEATURES_RESP
    | FlowModMsg _ -> FLOW_MOD
    | GroupModMsg _ -> GROUP_MOD
    | PacketInMsg _ -> PACKET_IN
    | PacketOutMsg _ -> PACKET_OUT
    | PortStatusMsg _ ->   PORT_STATUS
    | MultipartReq _ -> MULTIPART_REQ
    | MultipartReply _ -> MULTIPART_RESP
    | BarrierRequest ->   BARRIER_REQ
    | BarrierReply ->   BARRIER_RESP
    | Error _ -> ERROR

  let sizeof (msg : t) : int = match msg with
    | Hello -> Header.size
    | EchoRequest bytes -> Header.size + (String.length (Cstruct.to_string bytes))
    | EchoReply bytes -> Header.size + (String.length (Cstruct.to_string bytes))
    | FeaturesRequest -> Header.size
    | FeaturesReply _ -> Header.size + sizeof_ofp_switch_features
    | FlowModMsg fm -> Header.size + FlowMod.sizeof fm
    | GroupModMsg gm -> Header.size + GroupMod.sizeof gm
    | PacketInMsg pi -> Header.size + PacketIn.sizeof pi
    | PacketOutMsg po -> Header.size + PacketOut.sizeof po
    | PortStatusMsg _ -> Header.size + sizeof_ofp_port_status + sizeof_ofp_port
    | MultipartReq req -> Header.size + MultipartReq.sizeof req
    | MultipartReply _ -> failwith "NYI: sizeof MultipartReply"
    | BarrierRequest -> failwith "NYI: sizeof BarrierRequest"
    | BarrierReply -> failwith "NYI: sizeof BarrierReply"
    | Error _ -> failwith "NYI: sizeof Error"

  let to_string (msg : t) : string = match msg with
    | Hello -> "Hello"
    | Error _ -> "Error"
    | EchoRequest _ -> "EchoRequest"
    | EchoReply _ -> "EchoReply"
    | FeaturesRequest -> "FeaturesRequest"
    | FeaturesReply _ -> "FeaturesReply"
    | FlowModMsg _ -> "FlowMod"
    | GroupModMsg _ -> "GroupMod"
    | PacketInMsg _ -> "PacketIn"
    | PacketOutMsg _ -> "PacketOut"
    | PortStatusMsg _ -> "PortStatus"
    | MultipartReq _ -> "MultipartRequest"
    | MultipartReply _ -> "MultipartReply"
    | BarrierRequest -> "BarrierRequest"
    | BarrierReply -> "BarrierReply"

  (* let marshal (buf : Cstruct.t) (msg : message) : int = *)
  (*   let buf2 = (Cstruct.shift buf Header.size) in *)
  (*   set_ofp_header_version buf 0x04; *)
  (*   set_ofp_header_typ buf (msg_code_to_int (msg_code_of_message msg)); *)
  (*   set_ofp_header_length buf (sizeof msg); *)

  let blit_message (msg : t) (out : Cstruct.t) =
    match msg with
      | Hello ->
        Header.size
      | EchoRequest bytes
      | EchoReply bytes ->
        Cstruct.blit_from_string (Cstruct.to_string bytes) 0 out 0 (String.length (Cstruct.to_string bytes));
        Header.size + String.length (Cstruct.to_string bytes)
      | FeaturesRequest ->
        Header.size
      | FeaturesReply fr ->
        Header.size + SwitchFeatures.marshal out fr
      | FlowModMsg fm ->
        Header.size + FlowMod.marshal out fm
      | GroupModMsg gm ->
        Header.size + GroupMod.marshal out gm
      | PacketOutMsg po ->
        Header.size + PacketOut.marshal out po
      | MultipartReq mpr ->
        Header.size + MultipartReq.marshal out mpr
      | MultipartReply _ -> failwith "NYI: marshal MultipartReply"
      | BarrierRequest -> failwith "NYI: marshal BarrierRequest"
      | BarrierReply -> failwith "NYI: marshal BarrierReply"
      | PacketInMsg pi ->
        Header.size + PacketIn.marshal out pi
      | PortStatusMsg ps -> 
        Header.size + PortStatus.marshal out ps
      | Error _ -> failwith "NYI: marshall Error"


  let header_of xid msg =
    let open Header in
    { version = 0x04; type_code = msg_code_to_int (msg_code_of_message msg);
      length = sizeof msg; xid = xid }

  let marshal_body (msg : t) (buf : Cstruct.t) =
    let _ = blit_message msg buf in
    ()
    
  let marshal (xid : xid) (msg : t) : string =
    let sizeof_buf = sizeof msg in
    let hdr = header_of xid msg in
    let buf = Cstruct.create sizeof_buf in
    Header.marshal buf hdr;
    let _ = blit_message msg (Cstruct.shift buf Header.size) in
    Cstruct.to_string buf

  let parse (hdr : Header.t) (body_buf : string) : (xid * t) =
    let body_bits = Cstruct.of_string body_buf in
    let typ = match int_to_msg_code hdr.Header.type_code with
      | Some code -> code
      | None -> raise (Unparsable "unknown message code") in
    let msg = match typ with
      | HELLO -> Hello
      | ECHO_RESP -> EchoReply body_bits
      | FEATURES_RESP -> FeaturesReply (SwitchFeatures.parse body_bits)
      | PACKET_IN -> PacketInMsg (PacketIn.parse body_bits)
      | ECHO_REQ -> EchoRequest body_bits
      | PORT_STATUS -> PortStatusMsg (PortStatus.parse body_bits)
      | MULTIPART_RESP -> MultipartReply (MultipartReply.parse body_bits)
      | ERROR -> Error (Error.parse body_bits)
      | code -> raise (Unparsable (Printf.sprintf "unexpected message type %s" (string_of_msg_code typ))) in
    (hdr.Header.xid, msg)
end

let portsDescRequest = Message.MultipartReq portDescReq
