*&---------------------------------------------------------------------*
*&  Include  zabap_tcode_search_cls_rep
*&---------------------------------------------------------------------*

CLASS lcl_report DEFINITION INHERITING FROM zcl_ea_salv_table.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF t_output,
        tcode TYPE tcode,
        ttext TYPE ttext_stct,
        match TYPE p LENGTH 4 DECIMALS 3,
      END OF t_output,
      tt_output TYPE STANDARD TABLE OF t_output WITH EMPTY KEY.

    METHODS:
      set_grid IMPORTING container_name TYPE string,
      prepare_report IMPORTING query TYPE string custom_only TYPE abap_bool pattern_only TYPE abap_bool match_threshold TYPE float DEFAULT '0.7'.

  PROTECTED SECTION.
    METHODS:
      on_double_click REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_cache_status,
        empty       TYPE i VALUE 0,
        custom_only TYPE i VALUE 1,
        all         TYPE i VALUE 2,
      END OF c_cache_status.

    METHODS:
      direct_query IMPORTING query TYPE string custom_only TYPE abap_bool,
      fill_cache IMPORTING custom_only TYPE abap_bool,
      fill_output_from_cache IMPORTING query TYPE string match_threshold TYPE float.

    DATA:
      cache_status  TYPE i VALUE c_cache_status-empty,
      output        TYPE tt_output,
      cached_tcodes TYPE tt_output.
ENDCLASS.

CLASS lcl_report IMPLEMENTATION.
  METHOD prepare_report.
    FREE output.
    IF pattern_only = abap_true.
      direct_query( query = query custom_only = custom_only ).

    ELSE.
      fill_cache( custom_only ).
      fill_output_from_cache( query = query match_threshold = match_threshold ).

    ENDIF.

    SORT output BY match DESCENDING.
    set_data( REF #( output ) ).

    columns->set_fixed_text( column = 'MATCH' text = TEXT-c01 ).
  ENDMETHOD.

  METHOD set_grid.
    me->set_container( NEW cl_gui_custom_container( container_name = CONV char50( container_name ) ) ).
    SET HANDLER on_double_click FOR alv_table->get_event( ).
  ENDMETHOD.

  METHOD direct_query.
    DATA tcode_range TYPE RANGE OF tcode.

    APPEND VALUE #( sign = 'I' option = 'CP' low = query ) TO tcode_range.

    SELECT FROM tstc LEFT JOIN tstct ON tstct~sprsl = @sy-langu AND tstct~tcode = tstc~tcode
    FIELDS tstc~tcode, tstct~ttext, 1 AS match
    WHERE tstc~tcode IN @tcode_range AND ( @custom_only = @abap_false OR tstc~tcode LIKE 'Z%' OR tstc~tcode LIKE 'Y%' )
    INTO CORRESPONDING FIELDS OF TABLE @output.
  ENDMETHOD.

  METHOD fill_cache.
    IF cache_status = c_cache_status-all OR ( cache_status = c_cache_status-custom_only AND custom_only = abap_true ).
      RETURN.
    ENDIF.

    DATA tcode_range TYPE RANGE OF tcode.
    IF custom_only = abap_true.
      tcode_range = VALUE #( ( sign = 'I' option = 'CP' low = 'Y*' ) ( sign = 'I' option = 'CP' low = 'Z*' ) ).
    ELSEIF cache_status = c_cache_status-custom_only.
      tcode_range = VALUE #( ( sign = 'E' option = 'CP' low = 'Y*' ) ( sign = 'E' option = 'CP' low = 'Z*' ) ).
    ENDIF.

    SELECT FROM tstc LEFT JOIN tstct ON tstct~sprsl = @sy-langu AND tstct~tcode = tstc~tcode
    FIELDS tstc~tcode, tstct~ttext
    WHERE tstc~tcode IN @tcode_range AND ( @custom_only = @abap_false OR tstc~tcode LIKE 'Z%' OR tstc~tcode LIKE 'Y%' )
    APPENDING CORRESPONDING FIELDS OF TABLE @cached_tcodes.

    cache_status = COND #( WHEN custom_only = abap_true THEN c_cache_status-custom_only ELSE c_cache_status-all ).
  ENDMETHOD.

  METHOD fill_output_from_cache.
    LOOP AT cached_tcodes REFERENCE INTO DATA(tcode).
      DATA(maximum) = COND decfloat34( WHEN strlen( query ) > strlen( tcode->tcode ) THEN strlen( query ) ELSE strlen( tcode->tcode ) ).
      DATA(distance) = CONV decfloat34( distance( val1 = query val2 = tcode->tcode ) ).
      DATA(match) = ( maximum - distance ) / maximum.
      IF match > match_threshold.
        APPEND VALUE #( BASE tcode->* match = match ) TO output.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD on_double_click.
    IF row = 0.
      RETURN.
    ENDIF.
    IF column = 'TCODE'.
      DATA(row_ref) = REF #( output[ row ] ).
      CALL TRANSACTION row_ref->tcode WITH AUTHORITY-CHECK.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
