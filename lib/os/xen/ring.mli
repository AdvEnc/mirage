(*
 * Copyright (c) 2011 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

module type RING = sig
  type idx = int
  type req
  type res
  type fring

  val alloc : int -> (Gnttab.r * fring) Lwt.t
  val req_idx : fring -> int
  val pending_responses : fring -> int
  val free_requests : fring -> int
  val max_requests : fring -> int
  val write : fring -> req -> bool
  val writev : fring -> req list -> bool
  val readv : fring -> (idx -> res -> unit) -> unit
end

module Netif : sig
  module Rx : sig

    type req = Gnttab.num

    module Res : sig
      type flags = {
        checksum_blank: bool;
        data_validated: bool;
        more_data: bool;
        extra_info: bool;
      }
      type status = 
        | Size of int
        | Err of int
      type t = { off : int; flags : flags; status : status; }
    end

  end

  module Tx : sig
    module Req : sig
      type gso_type =
        | GSO_none
        | GSO_TCPv4

      type gso = {
        gso_size: int;
        gso_type: gso_type;
        gso_features: int;
      }

      type extra =
        | GSO of gso
        | Mcast_add of string
        | Mcast_del of string

      type flags = int

      type normal = {
        gref: Gnttab.num;
        offset: int;
        flags: flags;
        size: int;
      }

      type t =
       | Normal of normal 
       | Extra of extra
    end

    module Res : sig
      type status =  
       | Dropped | Error | OK | Null
      type t = status
    end
  end

  module Tx_t : sig
    type t
    val t : backend_domid:int -> (Gnttab.r * t) Lwt.t
    val write : t -> evtchn:int -> Tx.Req.t -> Tx.Res.t Lwt.t
    val poll : t -> unit
    val max_requests : t -> int
  end
end

module Blkif : sig
  type vdev = int

  module Req : sig
    type op =
      |Read |Write |Write_barrier |Flush

    type seg = {
      gref: Gnttab.num;
      first_sector: int;
      last_sector: int;
    }

    type t = {
      op: op;
      handle: vdev;
      sector: int64;
      segs: seg array;
    }
  end

  module Res : sig
    type status = 
      |OK |Error |Not_supported |Unknown of int

    type t = {
      op: Req.op;
      status: status;
    }
  end
end  

module Blkif_t : sig
  type t
  val t : backend_domid:int -> (Gnttab.r * t) Lwt.t
  val write : t -> evtchn:int -> Blkif.Req.t -> Blkif.Res.t Lwt.t
  val poll : t -> unit
  val max_requests : t -> int
end
 
module Console : sig
  type t
  external unsafe_write : t -> string -> int -> int = "caml_console_ring_write"
  external unsafe_read : t -> string -> int -> int = "caml_console_ring_read"
  val alloc : int -> (Gnttab.r * t) Lwt.t
  val alloc_initial : unit -> Gnttab.r * t
end

module Xenstore : sig
  type t
  external unsafe_write : t -> string -> int -> int = "caml_xenstore_ring_write"
  external unsafe_read : t -> string -> int -> int = "caml_xenstore_ring_read"
  val alloc_initial : unit -> Gnttab.r * t
end
