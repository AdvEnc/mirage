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

(** I/O page allocator.
    Xen requires that pages used for I/O with other domains are never moved
    in memory once they are granted to the remote domain. Bitstrings allocated
    via this module are guaranteed to never be moved by the garbage collector,
    as they are heap-allocated outside of the OCaml heap, and not registered
    as roots.
   *)

type page

(** Get free I/O page from the free pool *)
val get: unit -> page

(** Get n free I/O pages from the free pool *)
val get_n: int -> page list

(** Signal that we nolonger need an I/O page *)
val put: page -> unit

(** [with_page f] calls [f t] where [t] is a fresh page and then returns
    [t] to the free pool unless the user has called [detach] *)
val with_page: (page -> 'a Lwt.t) -> 'a Lwt.t

(** [with_pages n f] calls [f pages] where [pages] is a list of fresh pages
    where each page is returned to the pool unless the user has called [detach]*)
val with_pages: int -> (page list -> 'a Lwt.t) -> 'a Lwt.t

type view

(* Retrieve a view from the page. *)
val get_view : page -> view

(* Narrow the view away from the beginning by [n] bytes, returning the new view *)
val get_subview : view -> int -> view

(* Expand the view towards the beginning by [n] bytes, returning the new view *)
val get_superview: view -> int -> view

val set_view_len : view -> int -> view
val add_view_len : view -> int -> view
val get_view_len : view -> int

(** Return the current view as a bitstring *)
val to_bitstring: view -> Bitstring.t

(** Return the current view a substring (buf,off,len in bytes) *)
val to_substring: view -> string * int * int
