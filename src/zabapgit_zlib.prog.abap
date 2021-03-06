*&---------------------------------------------------------------------*
*&  Include           ZABAPGIT_ZLIB
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_convert DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_convert DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS:
      hex_to_bits
        IMPORTING iv_hex         TYPE xsequence
        RETURNING VALUE(rv_bits) TYPE string,
      bits_to_int
        IMPORTING iv_bits       TYPE clike
        RETURNING VALUE(rv_int) TYPE i,
      int_to_hex
        IMPORTING iv_int        TYPE i
        RETURNING VALUE(rv_hex) TYPE xstring.

ENDCLASS.                    "lcl_zlib_convert DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_convert IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_convert IMPLEMENTATION.

  METHOD hex_to_bits.

    DATA: lv_x   TYPE x LENGTH 1,
          lv_c   TYPE c LENGTH 1,
          lv_bit TYPE i,
          lv_hex TYPE xstring.


    lv_hex = iv_hex.
    WHILE NOT lv_hex IS INITIAL.
      lv_x = lv_hex.
      DO 8 TIMES.
        lv_bit = sy-index.
        GET BIT lv_bit OF lv_x INTO lv_c.
        CONCATENATE rv_bits lv_c INTO rv_bits.
      ENDDO.
      lv_hex = lv_hex+1.
    ENDWHILE.

  ENDMETHOD.                    "hex_to_bits

  METHOD bits_to_int.

    DATA: lv_c    TYPE c LENGTH 1,
          lv_bits TYPE string.

    lv_bits = iv_bits.

    WHILE NOT lv_bits IS INITIAL.
      lv_c = lv_bits.
      rv_int = rv_int * 2.
      rv_int = rv_int + lv_c.
      lv_bits = lv_bits+1.
    ENDWHILE.

  ENDMETHOD.                    "bits_to_int

  METHOD int_to_hex.

    DATA: lv_x TYPE x.


    lv_x = iv_int.
    rv_hex = lv_x.

  ENDMETHOD.                    "int_to_hex

ENDCLASS.                    "lcl_zlib_convert IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_stream DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_stream DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING iv_data TYPE xstring,
      take_bits
        IMPORTING iv_length      TYPE i
        RETURNING VALUE(rv_bits) TYPE string,
      take_int
        IMPORTING iv_length     TYPE i
        RETURNING VALUE(rv_int) TYPE i,
      remaining
        RETURNING VALUE(rv_length) TYPE i.

  PRIVATE SECTION.
    DATA: mv_compressed TYPE xstring,
          mv_bits       TYPE string.

ENDCLASS.                    "lcl_zlib_stream DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_stream IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_stream IMPLEMENTATION.

  METHOD constructor.

    mv_compressed = iv_data.

  ENDMETHOD.                    "constructor

  METHOD remaining.

    rv_length = xstrlen( mv_compressed ) + 1.

  ENDMETHOD.                    "remaining

  METHOD take_int.

    rv_int = lcl_zlib_convert=>bits_to_int( take_bits( iv_length ) ).

  ENDMETHOD.                    "take_int

  METHOD take_bits.

    DATA: lv_left  TYPE i,
          lv_index TYPE i,
          lv_x     TYPE x LENGTH 1.


    WHILE strlen( rv_bits ) < iv_length.
      IF mv_bits IS INITIAL.
        lv_x = mv_compressed(1).
        mv_bits = lcl_zlib_convert=>hex_to_bits( lv_x ).
        mv_compressed = mv_compressed+1.
      ENDIF.
      lv_left = iv_length - strlen( rv_bits ).
      IF lv_left >= strlen( mv_bits ).
        CONCATENATE mv_bits rv_bits INTO rv_bits.
        CLEAR mv_bits.
      ELSE.
        lv_index = strlen( mv_bits ) - lv_left.
        CONCATENATE mv_bits+lv_index(lv_left) rv_bits INTO rv_bits.
        mv_bits = mv_bits(lv_index).
      ENDIF.

    ENDWHILE.

  ENDMETHOD.                    "take_bits

ENDCLASS.                    "lcl_zlib_stream IMPLEMENTATION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_huffman DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_huffman DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES: ty_lengths TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

    CONSTANTS: c_maxbits TYPE i VALUE 15.

    METHODS:
      constructor
        IMPORTING it_lengths TYPE ty_lengths,
      get_count
        IMPORTING iv_index        TYPE i
        RETURNING VALUE(rv_value) TYPE i,
      get_symbol
        IMPORTING iv_index        TYPE i
        RETURNING VALUE(rv_value) TYPE i.

  PRIVATE SECTION.

    DATA: mt_count  TYPE STANDARD TABLE OF i WITH DEFAULT KEY,
          mt_symbol TYPE STANDARD TABLE OF i WITH DEFAULT KEY.

ENDCLASS.                    "lcl_zlib_huffman DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib_huffman DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib_huffman IMPLEMENTATION.

  METHOD get_count.
    READ TABLE mt_count INDEX iv_index INTO rv_value.     "#EC CI_SUBRC
  ENDMETHOD.                    "count

  METHOD get_symbol.
    READ TABLE mt_symbol INDEX iv_index INTO rv_value.    "#EC CI_SUBRC
  ENDMETHOD.                    "symbol

  METHOD constructor.

    DATA: lv_index  TYPE i,
          lt_offset TYPE TABLE OF i,
          lv_length LIKE LINE OF it_lengths,
          lv_prev   TYPE i,
          lv_count  LIKE LINE OF mt_count.

    FIELD-SYMBOLS: <lv_offset> LIKE LINE OF lt_offset,
                   <lv_symbol> LIKE LINE OF mt_symbol,
                   <lv_i>      LIKE LINE OF it_lengths.


    DO c_maxbits TIMES.
      APPEND 0 TO mt_count.
    ENDDO.
    LOOP AT it_lengths INTO lv_index.
      IF lv_index = 0.
        CONTINUE.
      ENDIF.
      READ TABLE mt_count INDEX lv_index ASSIGNING <lv_i>.
      ASSERT sy-subrc = 0.
      <lv_i> = <lv_i> + 1.
    ENDLOOP.

************

    APPEND 0 TO lt_offset.
    DO c_maxbits - 1 TIMES.
      READ TABLE mt_count INDEX sy-index INTO lv_count.
      ASSERT sy-subrc = 0.
      lv_prev = lv_prev + lv_count.
      APPEND lv_prev TO lt_offset.
    ENDDO.

    DO lines( it_lengths ) TIMES.
      APPEND 0 TO mt_symbol.
    ENDDO.
    DO lines( it_lengths ) TIMES.
      lv_index = sy-index.
      READ TABLE it_lengths INDEX lv_index INTO lv_length.
      ASSERT sy-subrc = 0.
      IF lv_length = 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_offset INDEX lv_length ASSIGNING <lv_offset>.
      ASSERT sy-subrc = 0.
      READ TABLE mt_symbol INDEX <lv_offset> + 1 ASSIGNING <lv_symbol>.
      ASSERT sy-subrc = 0.
      <lv_symbol> = lv_index - 1.
      <lv_offset> = <lv_offset> + 1.
    ENDDO.

  ENDMETHOD.                    "constructor

ENDCLASS.                    "lcl_zlib_huffman DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib DEFINITION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_decompress,
             raw            TYPE xstring,
             compressed_len TYPE i,
           END OF ty_decompress.

    CLASS-METHODS:
      decompress
        IMPORTING iv_compressed  TYPE xsequence
        RETURNING VALUE(rs_data) TYPE ty_decompress.

  PRIVATE SECTION.
    CONSTANTS: c_maxdcodes TYPE i VALUE 30.

    CLASS-DATA: gv_out      TYPE xstring,
                go_lencode  TYPE REF TO lcl_zlib_huffman,
                go_distcode TYPE REF TO lcl_zlib_huffman,
                go_stream   TYPE REF TO lcl_zlib_stream.

    TYPES: BEGIN OF ty_pair,
             length   TYPE i,
             distance TYPE i,
           END OF ty_pair.

    CLASS-METHODS:
      decode
        IMPORTING io_huffman       TYPE REF TO lcl_zlib_huffman
        RETURNING VALUE(rv_symbol) TYPE i,
      map_length
        IMPORTING iv_code          TYPE i
        RETURNING VALUE(rv_length) TYPE i,
      map_distance
        IMPORTING iv_code            TYPE i
        RETURNING VALUE(rv_distance) TYPE i,
      dynamic,
      fixed,
      read_pair
        IMPORTING iv_length      TYPE i
        RETURNING VALUE(rs_pair) TYPE ty_pair,
      copy_out
        IMPORTING is_pair TYPE ty_pair.

ENDCLASS.                    "lcl_zlib DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_zlib IMPLEMENTATION
*----------------------------------------------------------------------*
*
*----------------------------------------------------------------------*
CLASS lcl_zlib IMPLEMENTATION.

  METHOD decode.

    DATA: lv_bit   TYPE c LENGTH 1,
          lv_len   TYPE i,
          lv_count TYPE i,
          lv_code  TYPE i,
          lv_index TYPE i,
          lv_first TYPE i,
          lv_bits  TYPE string.


    DO lcl_zlib_huffman=>c_maxbits TIMES.
      lv_len = sy-index.

      lv_bit = go_stream->take_bits( 1 ).
      CONCATENATE lv_bits lv_bit INTO lv_bits.
      lv_code = lcl_zlib_convert=>bits_to_int( lv_bits ).
      lv_count = io_huffman->get_count( lv_len ).

      IF lv_code - lv_count < lv_first.
        rv_symbol = io_huffman->get_symbol( lv_index + lv_code - lv_first + 1 ).
        RETURN.
      ENDIF.
      lv_index = lv_index + lv_count.
      lv_first = lv_first + lv_count.
      lv_first = lv_first * 2.
    ENDDO.

  ENDMETHOD.                    "decode

  METHOD fixed.

    DATA: lt_lengths TYPE lcl_zlib_huffman=>ty_lengths.


    DO 144 TIMES.
      APPEND 8 TO lt_lengths.
    ENDDO.
    DO 112 TIMES.
      APPEND 9 TO lt_lengths.
    ENDDO.
    DO 24 TIMES.
      APPEND 7 TO lt_lengths.
    ENDDO.
    DO 8 TIMES.
      APPEND 8 TO lt_lengths.
    ENDDO.

    CREATE OBJECT go_lencode
      EXPORTING
        it_lengths = lt_lengths.

    CLEAR lt_lengths.
    DO c_maxdcodes TIMES.
      APPEND 5 TO lt_lengths.
    ENDDO.

    CREATE OBJECT go_distcode
      EXPORTING
        it_lengths = lt_lengths.

  ENDMETHOD.                    "fixed

  METHOD copy_out.

* copy one byte at a time, it is not possible to copy using
* string offsets, as it might copy data that does not exist
* in mv_out yet

    DATA: lv_distance TYPE i,
          lv_index    TYPE i,
          lv_x        TYPE x LENGTH 1.


    lv_distance = xstrlen( gv_out ) - is_pair-distance.
    DO is_pair-length TIMES.
      lv_index = sy-index - 1 + lv_distance.
      lv_x = gv_out+lv_index(1).
      CONCATENATE gv_out lv_x INTO gv_out IN BYTE MODE.
    ENDDO.

  ENDMETHOD.                    "copy_out

  METHOD dynamic.

    DATA: lv_nlen    TYPE i,
          lv_ndist   TYPE i,
          lv_ncode   TYPE i,
          lv_index   TYPE i,
          lv_length  TYPE i,
          lv_symbol  TYPE i,
          lt_order   TYPE TABLE OF i,
          lt_lengths TYPE lcl_zlib_huffman=>ty_lengths,
          lt_dists   TYPE lcl_zlib_huffman=>ty_lengths.

    FIELD-SYMBOLS: <lv_length> LIKE LINE OF lt_lengths.


    APPEND 16 TO lt_order.
    APPEND 17 TO lt_order.
    APPEND 18 TO lt_order.
    APPEND  0 TO lt_order.
    APPEND  8 TO lt_order.
    APPEND  7 TO lt_order.
    APPEND  9 TO lt_order.
    APPEND  6 TO lt_order.
    APPEND 10 TO lt_order.
    APPEND  5 TO lt_order.
    APPEND 11 TO lt_order.
    APPEND  4 TO lt_order.
    APPEND 12 TO lt_order.
    APPEND  3 TO lt_order.
    APPEND 13 TO lt_order.
    APPEND  2 TO lt_order.
    APPEND 14 TO lt_order.
    APPEND  1 TO lt_order.
    APPEND 15 TO lt_order.

    lv_nlen = go_stream->take_int( 5 ) + 257.
    lv_ndist = go_stream->take_int( 5 ) + 1.
    lv_ncode = go_stream->take_int( 4 ) + 4.

    DO 19 TIMES.
      APPEND 0 TO lt_lengths.
    ENDDO.

    DO lv_ncode TIMES.
      READ TABLE lt_order INDEX sy-index INTO lv_index.
      ASSERT sy-subrc = 0.
      lv_index = lv_index + 1.
      READ TABLE lt_lengths INDEX lv_index ASSIGNING <lv_length>.
      ASSERT sy-subrc = 0.
      <lv_length> = go_stream->take_int( 3 ).
    ENDDO.

    CREATE OBJECT go_lencode
      EXPORTING
        it_lengths = lt_lengths.

    CLEAR lt_lengths.
    WHILE lines( lt_lengths ) < lv_nlen + lv_ndist.
      lv_symbol = decode( go_lencode ).

      IF lv_symbol < 16.
        APPEND lv_symbol TO lt_lengths.
      ELSE.
        lv_length = 0.
        IF lv_symbol = 16.
          READ TABLE lt_lengths INDEX lines( lt_lengths ) INTO lv_length.
          ASSERT sy-subrc = 0.
          lv_symbol = go_stream->take_int( 2 ) + 3.
        ELSEIF lv_symbol = 17.
          lv_symbol = go_stream->take_int( 3 ) + 3.
        ELSE.
          lv_symbol = go_stream->take_int( 7 ) + 11.
        ENDIF.
        DO lv_symbol TIMES.
          APPEND lv_length TO lt_lengths.
        ENDDO.
      ENDIF.
    ENDWHILE.

    lt_dists = lt_lengths.
    DELETE lt_lengths FROM lv_nlen + 1.
    DELETE lt_dists TO lv_nlen.

    CREATE OBJECT go_lencode
      EXPORTING
        it_lengths = lt_lengths.

    CREATE OBJECT go_distcode
      EXPORTING
        it_lengths = lt_dists.

  ENDMETHOD.                    "dynamic

  METHOD read_pair.

    DATA: lv_symbol TYPE i.


    rs_pair-length = map_length( iv_length ).

    lv_symbol = decode( go_distcode ).
    rs_pair-distance = map_distance( lv_symbol ).

  ENDMETHOD.                    "read_pair

  METHOD map_distance.

    DEFINE _distance.
      rv_distance = go_stream->take_int( &1 ).
      rv_distance = rv_distance + &2.
    END-OF-DEFINITION.

    CASE iv_code.
      WHEN 0.
        _distance 0 1.
      WHEN 1.
        _distance 0 2.
      WHEN 2.
        _distance 0 3.
      WHEN 3.
        _distance 0 4.
      WHEN 4.
        _distance 1 5.
      WHEN 5.
        _distance 1 7.
      WHEN 6.
        _distance 2 9.
      WHEN 7.
        _distance 2 13.
      WHEN 8.
        _distance 3 17.
      WHEN 9.
        _distance 3 25.
      WHEN 10.
        _distance 4 33.
      WHEN 11.
        _distance 4 49.
      WHEN 12.
        _distance 5 65.
      WHEN 13.
        _distance 5 97.
      WHEN 14.
        _distance 6 129.
      WHEN 15.
        _distance 6 193.
      WHEN 16.
        _distance 7 257.
      WHEN 17.
        _distance 7 385.
      WHEN 18.
        _distance 8 513.
      WHEN 19.
        _distance 8 769.
      WHEN 20.
        _distance 9 1025.
      WHEN 21.
        _distance 9 1537.
      WHEN 22.
        _distance 10 2049.
      WHEN 23.
        _distance 10 3073.
      WHEN 24.
        _distance 11 4097.
      WHEN 25.
        _distance 11 6145.
      WHEN 26.
        _distance 12 8193.
      WHEN 27.
        _distance 12 12289.
      WHEN 28.
        _distance 13 16385.
      WHEN 29.
        _distance 13 24577.
      WHEN OTHERS.
        ASSERT 1 = 0.
    ENDCASE.

  ENDMETHOD.                    "map_distance

  METHOD map_length.

    DEFINE _length.
      rv_length = go_stream->take_int( &1 ).
      rv_length = rv_length + &2.
    END-OF-DEFINITION.

    CASE iv_code.
      WHEN 257.
        _length 0 3.
      WHEN 258.
        _length 0 4.
      WHEN 259.
        _length 0 5.
      WHEN 260.
        _length 0 6.
      WHEN 261.
        _length 0 7.
      WHEN 262.
        _length 0 8.
      WHEN 263.
        _length 0 9.
      WHEN 264.
        _length 0 10.
      WHEN 265.
        _length 1 11.
      WHEN 266.
        _length 1 13.
      WHEN 267.
        _length 1 15.
      WHEN 268.
        _length 1 17.
      WHEN 269.
        _length 2 19.
      WHEN 270.
        _length 2 23.
      WHEN 271.
        _length 2 27.
      WHEN 272.
        _length 2 31.
      WHEN 273.
        _length 3 35.
      WHEN 274.
        _length 3 43.
      WHEN 275.
        _length 3 51.
      WHEN 276.
        _length 3 59.
      WHEN 277.
        _length 4 67.
      WHEN 278.
        _length 4 83.
      WHEN 279.
        _length 4 99.
      WHEN 280.
        _length 4 115.
      WHEN 281.
        _length 5 131.
      WHEN 282.
        _length 5 163.
      WHEN 283.
        _length 5 195.
      WHEN 284.
        _length 5 227.
      WHEN 285.
        _length 0 258.
      WHEN OTHERS.
        ASSERT 1 = 0.
    ENDCASE.

  ENDMETHOD.                    "map_length

  METHOD decompress.

    DATA: lv_x      TYPE x LENGTH 1,
          lv_symbol TYPE i,
          lv_bfinal TYPE c LENGTH 1,
          lv_btype  TYPE c LENGTH 2.


    IF iv_compressed IS INITIAL.
      RETURN.
    ENDIF.

    CLEAR gv_out.
    CREATE OBJECT go_stream
      EXPORTING
        iv_data = iv_compressed.

    DO.
      lv_bfinal = go_stream->take_bits( 1 ).

      lv_btype = go_stream->take_bits( 2 ).
      CASE lv_btype.
        WHEN '01'.
          fixed( ).
        WHEN '10'.
          dynamic( ).
        WHEN OTHERS.
          ASSERT 1 = 0.
      ENDCASE.

      DO.
        lv_symbol = decode( go_lencode ).

        IF lv_symbol < 256.
          lv_x = lcl_zlib_convert=>int_to_hex( lv_symbol ).
          CONCATENATE gv_out lv_x INTO gv_out IN BYTE MODE.
        ELSEIF lv_symbol = 256.
          EXIT.
        ELSE.
          copy_out( read_pair( lv_symbol ) ).
        ENDIF.

      ENDDO.

      IF lv_bfinal = '1'.
        EXIT.
      ENDIF.

    ENDDO.

    rs_data-raw = gv_out.
    rs_data-compressed_len = xstrlen( iv_compressed ) - go_stream->remaining( ).

  ENDMETHOD.                    "decompress

ENDCLASS.                    "lcl_zlib IMPLEMENTATION