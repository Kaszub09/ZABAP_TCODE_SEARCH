*&---------------------------------------------------------------------*
*&  Include  zabap_tcode_search_cls_rep
*&---------------------------------------------------------------------*

CLASS lcl_report DEFINITION INHERITING FROM zcl_zabap_salv_report.
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
    set_data( EXPORTING create_table_copy = abap_false CHANGING data_table = output ).

    set_fixed_column_text( column = 'MATCH' text = TEXT-c01 ).
  ENDMETHOD.

  METHOD set_grid.

    DATA(container) = NEW cl_gui_custom_container( container_name = CONV char50( container_name ) ).

    "Need empty table for cl_salv_table factory so you can use f4 layout selection
    "Table must be of structured type, throws error otherwise
    TYPES: BEGIN OF t_dummy,
             dummy TYPE i,
           END OF t_dummy.
    CREATE DATA data_table_ref TYPE TABLE OF t_dummy.
    FIELD-SYMBOLS <data_table> TYPE STANDARD TABLE.
    ASSIGN data_table_ref->* TO <data_table>.

    cl_salv_table=>factory( EXPORTING r_container = container container_name = container_name
                            IMPORTING r_salv_table = alv_table CHANGING t_table = <data_table> ).
    SET HANDLER on_double_click FOR alv_table->get_event( ).
  ENDMETHOD.

  METHOD direct_query.
    DATA tcode_range TYPE RANGE OF tcode.
    APPEND VALUE #( sign = 'I' option = 'CP' low = query ) TO tcode_range.

    SELECT FROM tstc LEFT JOIN tstct ON tstct~sprsl = @sy-langu AND tstct~tcode = tstc~tcode
    FIELDS tstc~tcode, tstct~ttext, 1 AS match
    WHERE tstc~tcode IN @tcode_range
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
    CHECK row <> 0.
    IF column = 'TCODE'.
      DATA(cell_value_ref) = me->get_ref_to_cell_value( row = row column = column ).
      ASSIGN cell_value_ref->* TO FIELD-SYMBOL(<cell_value>).
      CALL TRANSACTION <cell_value>.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
