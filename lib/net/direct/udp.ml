(*
 * Copyright (c) 2010 Anil Madhavapeddy <anil@recoil.org>
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

open Lwt
open Nettypes
open Printf

type t = {
  ip : Ipv4.t;
  listeners: (int, (src:ipv4_addr -> dst:ipv4_addr -> source_port:int -> Bitstring.t -> unit Lwt.t)) Hashtbl.t
}

let input t ~src ~dst pkt =
  bitmatch pkt with
  | { source_port:16; dest_port:16; length:16;
      checksum:16; data:(length-8)*8:bitstring } ->
  if Hashtbl.mem t.listeners dest_port then begin
    let fn = Hashtbl.find t.listeners dest_port in
    fn ~src ~dst ~source_port data
  end else
    return ()

let udp_header = 16+16+16+16
let udp_header_bytes = udp_header / 8

(* UDP output needs the IPv4 header to generate the pseudo
   header for checksum calculation. Although we currently just
   set the checksum to 0 as it is optional *)
let writebuf t ~dest_ip ~source_port ~dest_port =
  (* Obtain an IPv4 writebuf *)
  lwt app_view = Ipv4.writebuf t.ip ~proto:`UDP ~dest_ip in
  let app_bs = OS.Io_page.to_bitstring app_view in 
  let _ = BITSTRING { source_port:16; dest_port:16; 0:16; 0:16 } app_bs in
  let udp_frame = OS.Io_page.get_subview app_view udp_header_bytes in
  return udp_frame

let output t app_view =
  let udp_view = OS.Io_page.get_superview app_view udp_header_bytes in
  (* set length *)
  let hbuf,hoff,hlen = OS.Io_page.to_bitstring udp_view in
  let length_bs = hbuf, (hoff + 32), 0 in
  let plen = OS.Io_page.get_view_len app_view in
  let _ = BITSTRING { plen: 16 } length_bs in
  Ipv4.output t.ip udp_view

let listen t port fn =
  if Hashtbl.mem t.listeners port then
    fail (Failure "UDP port already bound")
  else begin
    let th, u = Lwt.task () in
    Hashtbl.add t.listeners port fn;
    Lwt.on_cancel th (fun _ -> Hashtbl.remove t.listeners port);
    th
  end

let create ip =
  let listeners = Hashtbl.create 1 in
  let t = { ip; listeners } in
  let thread,_ = Lwt.task () in
  Ipv4.attach ip (`UDP (input t));
  Lwt.on_cancel thread (fun () ->
    printf "UDP: thread shutdown\n%!";
    Ipv4.detach ip `UDP
  );
  t, thread
