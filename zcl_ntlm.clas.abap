class ZCL_NTLM definition
  public
  final
  create public .

public section.
*"* public components of class ZCL_NTLM
*"* do not include other source files here!!!

  constants C_SIGNATURE type XSTRING value '4E544C4D53535000'. "#EC NOTEXT

  class-methods GET
    importing
      !IV_USERNAME type CLIKE
      !IV_PASSWORD type CLIKE
      !IV_DOMAIN type CLIKE
      !IV_URL type CLIKE
    returning
      value(RV_RESULT) type XSTRING .
protected section.
*"* protected components of class ZCL_NTLM
*"* do not include other source files here!!!

  types:
    ty_byte8 TYPE x LENGTH 8 .
  types:
    ty_byte24 TYPE x LENGTH 24 .
  TYPES: ty_byte2 TYPE x LENGTH 2.
  TYPES: ty_byte4 TYPE x LENGTH 4.
  TYPES:
    BEGIN OF ty_flags,
           negotiate_56 TYPE abap_bool,
           negotiate_key_exch TYPE abap_bool,
           negotiate_128 TYPE abap_bool,
           r1 TYPE abap_bool,
           r2 TYPE abap_bool,
           r3 TYPE abap_bool,
           negotiate_version TYPE abap_bool,
           r4 TYPE abap_bool,
           negotiate_target_info TYPE abap_bool,
           request_non_nt_session_key TYPE abap_bool,
           r5 TYPE abap_bool,
           negotiate_identity TYPE abap_bool,
           negotiate_extended_session_sec TYPE abap_bool,
           r6 TYPE abap_bool,
           target_type_server TYPE abap_bool,
           target_type_domain TYPE abap_bool,
           negotiate_always_sign TYPE abap_bool,
           r7 TYPE abap_bool,
           negotiate_oem_workstation_sup TYPE abap_bool,
           negotiate_oem_domain_supplied TYPE abap_bool,
           anonymous TYPE abap_bool,
           r8 TYPE abap_bool,
           negotiate_ntlm TYPE abap_bool,
           r9 TYPE abap_bool,
           negotiate_lm_key TYPE abap_bool,
           negotiate_datagram TYPE abap_bool,
           negotiate_seal TYPE abap_bool,
           negotiate_sign TYPE abap_bool,
           r10 TYPE abap_bool,
           request_target TYPE abap_bool,
           negotiate_oem TYPE abap_bool,
           negotiate_unicode TYPE abap_bool,
         END OF ty_flags.
  types:
    BEGIN OF ty_type1,
    flags type ty_flags,
  target TYPE xstring,
  workstation TYPE xstring,
  END OF ty_type1 .

  constants C_MESSAGE_TYPE_1 type XSTRING value '01000000'. "#EC NOTEXT
  constants C_MESSAGE_TYPE_2 type XSTRING value '02000000'. "#EC NOTEXT
  constants C_MESSAGE_TYPE_3 type XSTRING value '03000000'. "#EC NOTEXT

  class-methods LMV1_RESPONSE
    importing
      !IV_PASSWORD type STRING
      !IV_CHALLENGE type TY_BYTE8
    returning
      value(RV_RESPONSE) type XSTRING .
  class-methods NTLMV2_RESPONSE
    importing
      !IV_PASSWORD type STRING
      !IV_USERNAME type STRING
      !IV_TARGET type STRING
      !IV_CHALLENGE type TY_BYTE8
      !IV_INFO type XSTRING
    returning
      value(RV_RESPONSE) type XSTRING
    raising
      CX_STATIC_CHECK .
  class-methods NTLMV1_RESPONSE
    importing
      !IV_PASSWORD type STRING
      !IV_CHALLENGE type TY_BYTE8
    returning
      value(RV_RESPONSE) type TY_BYTE24 .
  class-methods TYPE_1_DECODE
    importing
      !IV_VALUE type STRING
    returning
      value(RS_DATA) type TY_TYPE1 .
  class-methods TYPE_2_ENCODE
    returning
      value(RV_VALUE) type STRING .
  class-methods TYPE_3_DECODE
    importing
      !IV_VALUE type STRING .
  class-methods TYPE_1_ENCODE
    returning
      value(RV_VALUE) type STRING .
  class-methods TYPE_2_DECODE
    importing
      !IV_VALUE type STRING
    returning
      value(RV_CHALLENGE) type XSTRING .
  class-methods TYPE_3_ENCODE
    importing
      !IV_PASSWORD type STRING
      !IV_CHALLENGE type TY_BYTE8
    returning
      value(RV_VALUE) type STRING
    raising
      CX_STATIC_CHECK .
private section.
*"* private components of class ZCL_NTLM
*"* do not include other source files here!!!
ENDCLASS.



CLASS ZCL_NTLM IMPLEMENTATION.


METHOD get.

* The MIT License (MIT)
*
* Copyright (c) 2015 Lars Hvam
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.

* https://msdn.microsoft.com/en-us/library/cc236621.aspx
* http://davenport.sourceforge.net/ntlm.html
* http://blogs.msdn.com/b/chiranth/archive/2013/09/21/ntlm-want-to-know-how-it-works.aspx
* http://www.innovation.ch/personal/ronald/ntlm.html

* todo, endianness? detect via signature?

  DATA: li_client TYPE REF TO if_http_client,
        lv_value  TYPE string,
        lv_url    TYPE string,
        lt_fields TYPE tihttpnvp.

  FIELD-SYMBOLS: <ls_field> LIKE LINE OF lt_fields.


  lv_url = iv_url. " convert type
  cl_http_client=>create_by_url(
    EXPORTING
      url    = lv_url
      ssl_id = 'ANONYM' " todo, as optional input?
    IMPORTING
      client = li_client ).

  li_client->propertytype_logon_popup = li_client->co_disabled.

  li_client->send( ).
  li_client->receive(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state         = 2
      http_processing_failed     = 3
      OTHERS                     = 4 ).
  IF sy-subrc <> 0.
* todo
    BREAK-POINT.
  ENDIF.

  li_client->response->get_header_fields( CHANGING fields = lt_fields ).

  READ TABLE lt_fields ASSIGNING <ls_field>
    WITH KEY name = 'www-authenticate' value = 'NTLM'.      "#EC NOTEXT
  IF sy-subrc <> 0.
* no NTML destination
    BREAK-POINT.
  ENDIF.

***********************************************

  lv_value = type_1_encode( ).
  CONCATENATE 'NTLM' lv_value INTO lv_value SEPARATED BY space.
  li_client->request->set_header_field(
      name  = 'authorization'
      value = lv_value ).                                   "#EC NOTEXT

  li_client->send( ).
  li_client->receive(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state         = 2
      http_processing_failed     = 3
      OTHERS                     = 4 ).
  IF sy-subrc <> 0.
* todo
  ENDIF.

  li_client->response->get_header_fields( CHANGING fields = lt_fields ).

  READ TABLE lt_fields ASSIGNING <ls_field>
    WITH KEY name = 'www-authenticate'.                     "#EC NOTEXT
  IF sy-subrc <> 0.
* no NTML destination
    BREAK-POINT.
  ENDIF.

  lv_value = <ls_field>-value+5.
  type_2_decode( lv_value ).

* todo
*  BREAK-POINT.

  li_client->close( ).

ENDMETHOD.


METHOD lmv1_response.

  CONSTANTS: lc_text TYPE xstring VALUE '4B47532140232425'. " KGS!@#$%

  DATA: lv_pass TYPE xstring,
        lv_lm_hash TYPE x LENGTH 21,
        lv_rd1  TYPE x LENGTH 7,
        lv_rd2  TYPE x LENGTH 7,
        lv_rd3  TYPE x LENGTH 7,
        lv_r1   TYPE x LENGTH 8,
        lv_r2   TYPE x LENGTH 8,
        lv_r3   TYPE x LENGTH 8.


  lv_pass = lcl_convert=>codepage_utf_8( to_upper( iv_password ) ).
* todo, special characters?
  lv_rd1 = lv_pass.
  lv_rd2 = lv_pass+7.

  lv_r1 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd1 )
      iv_plaintext = lc_text ).
  lv_r2 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd2 )
      iv_plaintext = lc_text ).

  CONCATENATE lv_r1 lv_r2 INTO lv_lm_hash IN BYTE MODE.

  lv_rd1 = lv_lm_hash.
  lv_rd2 = lv_lm_hash+7.
  lv_rd3 = lv_lm_hash+14.

  lv_r1 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd1 )
      iv_plaintext = iv_challenge ).
  lv_r2 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd2 )
      iv_plaintext = iv_challenge ).
  lv_r3 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd3 )
      iv_plaintext = iv_challenge ).

  CONCATENATE lv_r1 lv_r2 lv_r3 INTO rv_response IN BYTE MODE.

ENDMETHOD.


METHOD ntlmv1_response.

  DATA: lv_hash TYPE zcl_md4=>ty_byte16,
        lv_rd1  TYPE x LENGTH 7,
        lv_rd2  TYPE x LENGTH 7,
        lv_rd3  TYPE x LENGTH 7,
        lv_r1   TYPE x LENGTH 8,
        lv_r2   TYPE x LENGTH 8,
        lv_r3   TYPE x LENGTH 8.


  lv_hash = zcl_md4=>hash( iv_encoding = '4103'
                           iv_string   = iv_password ).

  lv_rd1 = lv_hash.
  lv_rd2 = lv_hash+7.
  lv_rd3 = lv_hash+14.

  lv_r1 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd1 )
      iv_plaintext = iv_challenge ).
  lv_r2 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd2 )
      iv_plaintext = iv_challenge ).
  lv_r3 = zcl_des=>encrypt(
      iv_key       = zcl_des=>parity_adjust( lv_rd3 )
      iv_plaintext = iv_challenge ).

  CONCATENATE lv_r1 lv_r2 lv_r3 INTO rv_response IN BYTE MODE.

ENDMETHOD.


METHOD ntlmv2_response.

  CONSTANTS: lc_signature TYPE xstring VALUE '01010000',
             lc_zero      TYPE xstring VALUE '00000000'.

  DATA: lv_xpass   TYPE xstring,
        lv_xtarget TYPE xstring,
        lv_data    TYPE xstring,
        lv_hmac    TYPE xstring,
        lv_random  TYPE xstring,
        lv_time    TYPE xstring,
        lv_blob    TYPE xstring,
        lv_v2hash  TYPE xstring,
        lv_key     TYPE xstring.


  lv_key = zcl_md4=>hash( iv_encoding = '4103'
                          iv_string   = iv_password ).

  lv_xpass = lcl_convert=>codepage_4103( to_upper( iv_username ) ).
  lv_xtarget = lcl_convert=>codepage_4103( iv_target ) .
  CONCATENATE lv_xpass lv_xtarget INTO lv_data IN BYTE MODE.

  lv_v2hash = lcl_util=>hmac_md5( iv_key  = lv_key
                                  iv_data = lv_data ).

*  lv_time = '0090D336B734C301'.
  lv_time = lcl_util=>since_epoc_hex( ).
  lv_random = lcl_util=>random_nonce( ).

  CONCATENATE lc_signature lc_zero lv_time
    lv_random lc_zero iv_info lc_zero
    INTO lv_blob IN BYTE MODE.
  CONCATENATE iv_challenge lv_blob
    INTO lv_data IN BYTE MODE.

  lv_hmac = lcl_util=>hmac_md5( iv_key  = lv_v2hash
                                iv_data = lv_data ).

  CONCATENATE lv_hmac lv_blob INTO rv_response IN BYTE MODE.

ENDMETHOD.


METHOD type_1_decode.

  DATA: lo_reader TYPE REF TO lcl_reader.


  CREATE OBJECT lo_reader
    EXPORTING
      iv_value = iv_value
      iv_type  = c_message_type_1.

  rs_data-flags = lo_reader->flags( ).

* domain/target name
  rs_data-target = lo_reader->fields( ).

* workstation fields
  rs_data-workstation = lo_reader->fields( ).

* todo
  BREAK-POINT.

ENDMETHOD.


METHOD type_1_encode.

  DATA: lo_writer TYPE REF TO lcl_writer,
        ls_flags  TYPE ty_flags.


  CREATE OBJECT lo_writer
    EXPORTING
      iv_type = c_message_type_1.

* minimal flags, Negotiate NTLM and Negotiate unicode
  ls_flags-negotiate_ntlm = abap_true.
  ls_flags-negotiate_unicode = abap_true.

  lo_writer->flags( ls_flags ).

  rv_value = lo_writer->message( ).

ENDMETHOD.


METHOD type_2_decode.

  DATA: ls_flags       TYPE ty_flags,
        lv_tinfo       TYPE xstring,
        lv_tname       TYPE xstring,
        lo_reader      TYPE REF TO lcl_reader.


  CREATE OBJECT lo_reader
    EXPORTING
      iv_value = iv_value
      iv_type  = c_message_type_2.

* target name
  lv_tname = lo_reader->fields( ).

* flags
  ls_flags = lo_reader->flags( ).

* challenge
  rv_challenge = lo_reader->raw( 8 ).

* reserved
  lo_reader->skip( 8 ).

* target info
  lv_tinfo = lo_reader->fields( ).

*  BREAK-POINT.

ENDMETHOD.


METHOD type_2_encode.

  DATA: lo_writer TYPE REF TO lcl_writer.


  CREATE OBJECT lo_writer
    EXPORTING
      iv_type = c_message_type_2.

* todo

  rv_value = lo_writer->message( ).

ENDMETHOD.


METHOD type_3_decode.

  DATA: lv_lm_resp     TYPE xstring,
        lv_ntlm_resp   TYPE xstring,
        lv_target_name TYPE xstring,
        lv_user_name   TYPE xstring,
        lv_workst_name TYPE xstring,
        lv_session_key TYPE xstring,
        ls_flags       TYPE ty_flags,
        lo_reader      TYPE REF TO lcl_reader.


  CREATE OBJECT lo_reader
    EXPORTING
      iv_value = iv_value
      iv_type  = c_message_type_3.

* LM challenge response
  lv_lm_resp = lo_reader->fields( ).

* NTLM challenge response
  lv_ntlm_resp = lo_reader->fields( ).

* domain/target name
  lv_target_name = lo_reader->fields( ).

* user name
  lv_user_name = lo_reader->fields( ).

* workstation name
  lv_workst_name = lo_reader->fields( ).

* encrypted random session key
  lv_session_key = lo_reader->fields( ).

* negotiate flags
  ls_flags = lo_reader->flags( ).

* todo

*  BREAK-POINT.

ENDMETHOD.


METHOD type_3_encode.

  DATA: lv_lm_resp     TYPE xstring,
        lv_session_key TYPE xstring,
        lv_ntlm        TYPE xstring,
        lo_writer      TYPE REF TO lcl_writer,
        lv_data        TYPE xstring,
        ls_flags       TYPE ty_flags.


  CREATE OBJECT lo_writer
    EXPORTING
      iv_type = c_message_type_2.

* LM challenge response
  lv_lm_resp = lmv1_response(
      iv_password  = iv_password
      iv_challenge = iv_challenge ).
  lo_writer->fields( lv_lm_resp ).

* NTLM challenge response
  lv_ntlm = ntlmv1_response(
      iv_password  = iv_password
      iv_challenge = iv_challenge ).
  lo_writer->fields( lv_ntlm ).

* domain/target name
  lo_writer->fields( lv_data ).

* user name
  lo_writer->fields( lv_data ).

* workstation name
  lo_writer->fields( lv_data ).

* encrypted random session key
  lv_session_key = zcl_arc4=>encrypt_hex(
    iv_key        = zcl_md4=>hash_hex(
                      zcl_md4=>hash( iv_encoding = '4103'
                                     iv_string = 'Password' ) )
    iv_plaintext  = '55555555555555555555555555555555' ).
  lo_writer->fields( lv_session_key ).

* negotiate flags
  lo_writer->flags( ls_flags ).

* MIC?
* todo

* fields
*workstation name
*username
*target name
*ntlm response
*lm response

  rv_value = lo_writer->message( ).

ENDMETHOD.
ENDCLASS.