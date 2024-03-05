*&---------------------------------------------------------------------*
*& Report zabap_tcode_search
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zabap_tcode_search.

"=================================================================
"-----------------------------------------------------------------
DATA search_text TYPE string.
DATA custom_only TYPE abap_bool VALUE abap_true.
DATA match_pattern TYPE abap_bool.
DATA threshold TYPE p LENGTH 4 DECIMALS 3 VALUE '0.300'.

INCLUDE zabap_tcode_search_cls_rep.

START-OF-SELECTION.
  DATA(report) = NEW lcl_report( sy-repid ).
  report->set_grid( |RESULT_CONTAINER| ).
  SET SCREEN 1.

MODULE user_command_0001 INPUT.
  CASE sy-ucomm.
    WHEN 'SEARCH'.
      report->prepare_report( query = search_text custom_only = custom_only pattern_only = match_pattern match_threshold = CONV #( threshold ) ).
      report->display_data( ).
  ENDCASE.
ENDMODULE.
