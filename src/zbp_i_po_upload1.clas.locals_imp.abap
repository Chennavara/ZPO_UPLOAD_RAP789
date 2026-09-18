    CLASS lhc_upload DEFINITION

      INHERITING FROM cl_abap_behavior_handler.

      PRIVATE SECTION.

        METHODS get_global_authorizations
          FOR GLOBAL AUTHORIZATION
          IMPORTING
            REQUEST requested_authorizations FOR Upload
          RESULT result.

        METHODS uploadexcel
          FOR MODIFY
          IMPORTING keys
          FOR ACTION Upload~UploadExcel
          RESULT result.

        METHODS createpo
          FOR MODIFY
          IMPORTING keys
          FOR ACTION Upload~CreatePO
          RESULT result.

METHODS autouploadoncreate
  FOR DETERMINE ON SAVE
  IMPORTING keys
  FOR Upload~AutoUploadOnCreate.

    ENDCLASS.



    CLASS lhc_upload IMPLEMENTATION.


      "#################################################################
      "# GLOBAL AUTHORIZATION
      "#################################################################

      METHOD get_global_authorizations.

        result-%create =
          if_abap_behv=>auth-allowed.

        result-%update =
          if_abap_behv=>auth-allowed.

        result-%delete =
          if_abap_behv=>auth-allowed.

        result-%action-UploadExcel =
          if_abap_behv=>auth-allowed.

        result-%action-CreatePO =
          if_abap_behv=>auth-allowed.

      ENDMETHOD.



      "#################################################################
      "#
      "# ACTION 1 : UPLOAD EXCEL
      "#
      "#################################################################

      METHOD uploadexcel.


        "==========================================================
        " STEP 1 : READ UPLOADED FILE
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          FIELDS
          (
            Attachment
            FileName
            MimeType
          )

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_upload).


        IF lt_upload IS INITIAL.
          RETURN.
        ENDIF.


        DATA(ls_upload) =
          lt_upload[ 1 ].



        "==========================================================
        " STEP 2 : CHECK ATTACHMENT
        "==========================================================

        IF ls_upload-Attachment IS INITIAL.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            UPDATE FIELDS
            (
              Status
              Message
            )

            WITH VALUE #(
              (
                %tky =
                  keys[ 1 ]-%tky

                Status =
                  'ERROR'

                Message =
                  'Please select an Excel file first.'
              )
            ).


          READ ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            ALL FIELDS

            WITH CORRESPONDING #( keys )

            RESULT DATA(lt_no_file_result).


          result =
            VALUE #(
              FOR ls_no_file IN lt_no_file_result
              (
                %tky =
                  ls_no_file-%tky

                %param =
                  ls_no_file
              )
            ).


          RETURN.

        ENDIF.



        "==========================================================
        " STEP 3 : EXCEL STRUCTURE
        "
        " A  PO Type
        " B  Company Code
        " C  Purchasing Org
        " D  Purchasing Group
        " E  Supplier
        " F  PO Date
        " G  Currency
        " H  Material
        " I  Item Text
        " J  Material Group
        " K  Plant
        " L  Quantity
        " M  UOM
        " N  Net Price
        " O  Tax Code
        "==========================================================

        TYPES:
          BEGIN OF ty_excel,

            potype           TYPE string,
            companycode      TYPE string,
            purchasingorg    TYPE string,
            purchasinggroup  TYPE string,
            supplier         TYPE string,
            podate           TYPE string,
            currency         TYPE string,

            material         TYPE string,
            itemtext         TYPE string,
            materialgroup    TYPE string,
            plant            TYPE string,
            quantity         TYPE string,
            uom              TYPE string,
            netprice         TYPE string,
            "netprice         TYPE i,
            taxcode          TYPE string,

          END OF ty_excel.


        DATA lt_excel
          TYPE STANDARD TABLE OF ty_excel
          WITH EMPTY KEY.



    "==========================================================
    " STEP 4 : READ XLSX USING XCO
    "==========================================================

    DATA lv_file_content TYPE xstring.

    lv_file_content = ls_upload-Attachment.


    IF lv_file_content IS INITIAL.

      MODIFY ENTITIES OF ZI_PO_UPLOAD1 IN LOCAL MODE

        ENTITY Upload

        UPDATE FIELDS
        (
          Status
          Message
        )

        WITH VALUE #(
          (
            %tky    = keys[ 1 ]-%tky
            Status  = 'ERROR'
            Message = 'Excel attachment is empty.'
          )
        ).

      RETURN.

    ENDIF.


    "----------------------------------------------------------
    " Create XLSX read access
    "----------------------------------------------------------

    DATA(lo_read_access) =
      xco_cp_xlsx=>document->for_file_content(
        lv_file_content
      )->read_access( ).


    "----------------------------------------------------------
    " Get first worksheet
    "----------------------------------------------------------

    DATA(lo_worksheet) =
      lo_read_access->get_workbook(
      )->worksheet->at_position( 1 ).



    "==========================================================
    " STEP 5 : SELECT EXCEL RANGE A2 TO O
    "==========================================================

    DATA(lo_selection_pattern) =
      xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column(
        xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->to_column(
        xco_cp_xlsx=>coordinate->for_alphabetic_value( 'O' )
      )->from_row(
        xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
      )->get_pattern( ).



    "==========================================================
    " STEP 6 : READ EXCEL INTO LT_EXCEL
    "==========================================================

    lo_worksheet->select(
      lo_selection_pattern
    )->row_stream(
    )->operation->write_to(
      REF #( lt_excel )
    )->set_value_transformation(
      xco_cp_xlsx_read_access=>value_transformation->string_value
    )->execute( ).





        "==========================================================
        " STEP 7 : REMOVE EMPTY ROWS
        "==========================================================

        DELETE lt_excel
          WHERE material IS INITIAL.



        "==========================================================
        " STEP 8 : CHECK EXCEL DATA
        "==========================================================

        IF lt_excel IS INITIAL.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            UPDATE FIELDS
            (
              Status
              Message
            )

            WITH VALUE #(
              (
                %tky =
                  keys[ 1 ]-%tky

                Status =
                  'ERROR'

                Message =
                  'No PO data found in Excel.'
              )
            ).


          READ ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            ALL FIELDS

            WITH CORRESPONDING #( keys )

            RESULT DATA(lt_empty_result).


          result =
            VALUE #(
              FOR ls_empty IN lt_empty_result
              (
                %tky =
                  ls_empty-%tky

                %param =
                  ls_empty
              )
            ).


          RETURN.

        ENDIF.



        "==========================================================
        " STEP 9 : CLEAN QUANTITY / NET PRICE
        "==========================================================

        LOOP AT lt_excel
          ASSIGNING FIELD-SYMBOL(<ls_excel>).


          CONDENSE <ls_excel>-quantity
            NO-GAPS.


          CONDENSE <ls_excel>-netprice
            NO-GAPS.


          REPLACE ALL OCCURRENCES OF ','
            IN <ls_excel>-quantity
            WITH ''.


          REPLACE ALL OCCURRENCES OF ','
            IN <ls_excel>-netprice
            WITH ''.


        ENDLOOP.



        "==========================================================
        " STEP 10 : GET HEADER FROM FIRST EXCEL ROW
        "==========================================================

        DATA(ls_first) =
          lt_excel[ 1 ].



        "==========================================================
        " STEP 11 : UPDATE PO HEADER
        "==========================================================

        TRY.

            MODIFY ENTITIES OF ZI_PO_UPLOAD1
              IN LOCAL MODE

              ENTITY Upload

              UPDATE FIELDS
              (
                PurchaseOrderType
                CompanyCode
                PurchasingOrganization
                PurchasingGroup
                Supplier
                PurchaseOrderDate
                DocumentCurrency
                TotalRows
                Success
                Failed
                Status
                Message
              )

              WITH VALUE #(
                (
                  %tky =
                    keys[ 1 ]-%tky


                  PurchaseOrderType =
                    ls_first-potype


                  CompanyCode =
                    ls_first-companycode


                  PurchasingOrganization =
                    ls_first-purchasingorg


                  PurchasingGroup =
                    ls_first-purchasinggroup


                  Supplier =
                    ls_first-supplier


                  PurchaseOrderDate =
                    CONV #( ls_first-podate )


                  DocumentCurrency =
                    ls_first-currency


                  TotalRows =
                    lines( lt_excel )


                  Success =
                    0


                  Failed =
                    0


                  Status =
                    'UPLOADED'


                  Message =
                    'Excel uploaded successfully. Click Create PO.'
                )
              ).


          CATCH cx_root INTO DATA(lx_header).

            MODIFY ENTITIES OF ZI_PO_UPLOAD1
              IN LOCAL MODE

              ENTITY Upload

              UPDATE FIELDS
              (
                Status
                Message
              )

              WITH VALUE #(
                (
                  %tky =
                    keys[ 1 ]-%tky

                  Status =
                    'ERROR'

                  Message =
                    lx_header->get_text( )
                )
              ).

            RETURN.

        ENDTRY.



        "==========================================================
        " STEP 12 : READ OLD PREVIEW ITEMS
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload BY \_Items

          ALL FIELDS

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_old_items).



        "==========================================================
        " STEP 13 : DELETE OLD PREVIEW ITEMS
        "==========================================================

        IF lt_old_items IS NOT INITIAL.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY _Item

            DELETE FROM VALUE #(
              FOR ls_old_item IN lt_old_items
              (
                %tky =
                  ls_old_item-%tky
              )
            ).

        ENDIF.



        "==========================================================
        " STEP 14 : CREATE PREVIEW ITEM ROWS
        "==========================================================

        TRY.

            MODIFY ENTITIES OF ZI_PO_UPLOAD1
              IN LOCAL MODE

              ENTITY Upload

              CREATE BY \_Items

              FIELDS
              (
                RowNo
                PurchaseOrderItem
                Material
                ItemText
                MaterialGroup
                Plant
                Quantity
                UOM
                NetPrice
                Currency
                TaxCode
                Status
                Message
              )

              WITH VALUE #(
                (
                  %tky =
                    keys[ 1 ]-%tky


                  %target = VALUE #(

                    FOR ls_excel IN lt_excel
                    INDEX INTO lv_index

                    (
                      %cid =
                        |EXCELITEM{ lv_index }|


                      RowNo =
                        lv_index


                      PurchaseOrderItem =
                        |{ lv_index * 10
                             WIDTH = 5
                             ALIGN = RIGHT
                             PAD = '0' }|


                      Material =
                        ls_excel-material


                      ItemText =
                        ls_excel-itemtext


                      MaterialGroup =
                        ls_excel-materialgroup


                      Plant =
                        ls_excel-plant


                      Quantity =
                        CONV #( ls_excel-quantity )


                      UOM =
                        ls_excel-uom


                      NetPrice =
                      " CONV #( '15581.59' )
                      CONV #( ls_excel-netprice )


                      Currency =
                        ls_excel-currency


                      TaxCode =
                        ls_excel-taxcode


                      Status =
                        'READY'


                      Message =
                        'Ready for PO creation'
                    )

                  )

                )
              )

              MAPPED DATA(preview_mapped)
              FAILED DATA(preview_failed)
              REPORTED DATA(preview_reported).


          CATCH cx_root INTO DATA(lx_item).

            MODIFY ENTITIES OF ZI_PO_UPLOAD1
              IN LOCAL MODE

              ENTITY Upload

              UPDATE FIELDS
              (
                Status
                Message
              )

              WITH VALUE #(
                (
                  %tky =
                    keys[ 1 ]-%tky

                  Status =
                    'ERROR'

                  Message =
                    lx_item->get_text( )
                )
              ).

            RETURN.

        ENDTRY.



        "==========================================================
        " STEP 15 : CHECK PREVIEW CREATION FAILURE
        "==========================================================

        IF preview_failed-_item IS NOT INITIAL.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            UPDATE FIELDS
            (
              Status
              Message
            )

            WITH VALUE #(
              (
                %tky =
                  keys[ 1 ]-%tky

                Status =
                  'ERROR'

                Message =
                  'Error while creating Excel preview rows.'
              )
            ).

          RETURN.

        ENDIF.



        "==========================================================
        " STEP 16 : RETURN UPDATED ROOT
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          ALL FIELDS

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_upload_result).


        result =
          VALUE #(
            FOR ls_result IN lt_upload_result
            (
              %tky =
                ls_result-%tky

              %param =
                ls_result
            )
          ).


      ENDMETHOD.



      "#################################################################
      "#
      "# ACTION 2 : CREATE PURCHASE ORDER
      "#
      "#################################################################

      METHOD createpo.


        "==========================================================
        " STEP 1 : READ PO HEADER
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          ALL FIELDS

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_header).


        IF lt_header IS INITIAL.
          RETURN.
        ENDIF.


        DATA(ls_header) =
          lt_header[ 1 ].



        "==========================================================
        " STEP 2 : CHECK EXCEL STATUS
        "==========================================================

        IF ls_header-Status <> 'UPLOADED'.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            UPDATE FIELDS
            (
              Status
              Message
            )

            WITH VALUE #(
              (
                %tky =
                  keys[ 1 ]-%tky

                Status =
                  'ERROR'

                Message =
                  'Upload Excel before creating the PO.'
              )
            ).


          READ ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            ALL FIELDS

            WITH CORRESPONDING #( keys )

            RESULT DATA(lt_status_result).


          result =
            VALUE #(
              FOR ls_status IN lt_status_result
              (
                %tky =
                  ls_status-%tky

                %param =
                  ls_status
              )
            ).


          RETURN.

        ENDIF.



        "==========================================================
        " STEP 3 : READ PREVIEW ITEMS
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload BY \_Items

          ALL FIELDS

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_items).



        "==========================================================
        " STEP 4 : CHECK ITEMS
        "==========================================================

        IF lt_items IS INITIAL.

          MODIFY ENTITIES OF ZI_PO_UPLOAD1
            IN LOCAL MODE

            ENTITY Upload

            UPDATE FIELDS
            (
              Status
              Message
            )

            WITH VALUE #(
              (
                %tky =
                  keys[ 1 ]-%tky

                Status =
                  'ERROR'

                Message =
                  'No PO items found. Upload Excel first.'
              )
            ).

          RETURN.

        ENDIF.



        "==========================================================
        " STEP 5 : BUILD PO HEADER FOR I_PURCHASEORDERTP_2
        "==========================================================

        DATA(ls_po_header) =
          VALUE I_PurchaseOrderTP_2(

            PurchaseOrderType =
              ls_header-PurchaseOrderType

            CompanyCode =
              ls_header-CompanyCode

            PurchasingOrganization =
              ls_header-PurchasingOrganization

            PurchasingGroup =
              ls_header-PurchasingGroup

            Supplier =
              ls_header-Supplier

            PurchaseOrderDate =
              ls_header-PurchaseOrderDate

            DocumentCurrency =
              ls_header-DocumentCurrency

          ).



        "==========================================================
        " STEP 6 : BUILD PO ITEMS
        "==========================================================

        DATA lt_po_items
          TYPE STANDARD TABLE OF I_PurchaseOrderItemTP_2
          WITH EMPTY KEY.


        LOOP AT lt_items
          INTO DATA(ls_item).


          APPEND VALUE I_PurchaseOrderItemTP_2(

            PurchaseOrderItem =
              ls_item-PurchaseOrderItem

            Material =
              ls_item-Material

            PurchaseOrderItemText =
              ls_item-ItemText

            MaterialGroup =
              ls_item-MaterialGroup

            Plant =
              ls_item-Plant

            OrderQuantity =
              ls_item-Quantity

            PurchaseOrderQuantityUnit =
              ls_item-UOM

            OrderPriceUnit =
              ls_item-UOM

            NetPriceAmount =
              "CONV #( '15581.59' )
              ls_item-NetPrice

            NetPriceQuantity =
              1

            DocumentCurrency =
              ls_item-Currency

            TaxCode =
              ls_item-TaxCode

          ) TO lt_po_items.


        ENDLOOP.



        "==========================================================
        " STEP 7 : CREATE PURCHASE ORDER
        "==========================================================
CLEAR:
  zbp_i_po_upload1=>gt_po_mapped,
  zbp_i_po_upload1=>gt_po_link.

        MODIFY ENTITIES OF I_PurchaseOrderTP_2

          ENTITY PurchaseOrder

            CREATE SET FIELDS

            WITH VALUE #(
              (
                VALUE #(

                  BASE CORRESPONDING #(
                    ls_po_header
                    CHANGING CONTROL
                  )

                  %cid =
                    'PO001'

                )
              )
            )


            CREATE BY \_PurchaseOrderItem

            SET FIELDS

            WITH VALUE #(
              (
                %cid_ref =
                  'PO001'


                %target = VALUE #(

                  FOR ls_po_item IN lt_po_items
                  INDEX INTO lv_po_index

                  (
                    VALUE #(

                      BASE CORRESPONDING #(
                        ls_po_item
                        CHANGING CONTROL
                      )

                      %cid =
                        |ITEM{ lv_po_index }|

                    )
                  )

                )

              )
            )


          MAPPED
            DATA(po_mapped)

          FAILED
            DATA(po_failed)

          REPORTED
            DATA(po_reported).


    "==========================================================
    " STEP 8 : COLLECT + SHOW SAP PO MESSAGES IN FIORI
    "==========================================================

    DATA:
      lv_message TYPE string,
      lv_msg     TYPE string.


    "----------------------------------------------------------
    " HEADER MESSAGES FROM I_PurchaseOrderTP_2
    "----------------------------------------------------------

    LOOP AT po_reported-purchaseorder
      ASSIGNING FIELD-SYMBOL(<ls_header_msg>).

      IF <ls_header_msg>-%msg IS BOUND.

        lv_msg =
          <ls_header_msg>-%msg->if_message~get_text( ).

        IF lv_message IS INITIAL.

          lv_message =
            lv_msg.

        ELSE.

          lv_message =
            |{ lv_message }; { lv_msg }|.

        ENDIF.


        "Show original SAP message automatically in Fiori
        APPEND VALUE #(
          %tky =
            keys[ 1 ]-%tky

          %msg =
            <ls_header_msg>-%msg
        ) TO reported-upload.

      ENDIF.

    ENDLOOP.



    "----------------------------------------------------------
    " ITEM MESSAGES FROM I_PurchaseOrderTP_2
    "----------------------------------------------------------

    LOOP AT po_reported-purchaseorderitem
      ASSIGNING FIELD-SYMBOL(<ls_item_msg>).

      IF <ls_item_msg>-%msg IS BOUND.

        lv_msg =
          <ls_item_msg>-%msg->if_message~get_text( ).

        IF lv_message IS INITIAL.

          lv_message =
            lv_msg.

        ELSE.

          lv_message =
            |{ lv_message }; { lv_msg }|.

        ENDIF.


        "Show original SAP item error automatically in Fiori
        APPEND VALUE #(
          %tky =
            keys[ 1 ]-%tky

          %msg =
            <ls_item_msg>-%msg
        ) TO reported-upload.

      ENDIF.

    ENDLOOP.



    "==========================================================
    " STEP 9 : CHECK MODIFY FAILURE
    "==========================================================

    IF po_failed-purchaseorder IS NOT INITIAL
    OR po_failed-purchaseorderitem IS NOT INITIAL.


      "--------------------------------------------------------
      " If SAP returned FAILED but no REPORTED message
      "--------------------------------------------------------

      IF lv_message IS INITIAL.


        IF po_failed-purchaseorder IS NOT INITIAL.

          DATA(ls_failed_header) =
            po_failed-purchaseorder[ 1 ].

          lv_message =
            |PO header failed. RAP fail cause: { ls_failed_header-%fail-cause }|.


        ELSEIF po_failed-purchaseorderitem IS NOT INITIAL.

          DATA(ls_failed_po_item) =
            po_failed-purchaseorderitem[ 1 ].

          lv_message =
            |PO item failed. RAP fail cause: { ls_failed_po_item-%fail-cause }|.

        ELSE.

          lv_message =
            'Purchase Order creation failed.'.

        ENDIF.


        "Create our own Fiori error message
        APPEND VALUE #(
          %tky =
            keys[ 1 ]-%tky

          %msg =
            new_message_with_text(
              severity =
                if_abap_behv_message=>severity-error

              text =
                lv_message
            )
        ) TO reported-upload.

      ENDIF.



      "--------------------------------------------------------
      " Update Upload Header
      "--------------------------------------------------------

      MODIFY ENTITIES OF ZI_PO_UPLOAD1
        IN LOCAL MODE

        ENTITY Upload

        UPDATE FIELDS
        (
          Status
          Success
          Failed
          Message
        )

        WITH VALUE #(
          (
            %tky =
              keys[ 1 ]-%tky

            Status =
              'ERROR'

            Success =
              0

            Failed =
              lines( lt_items )

            Message =
              lv_message
          )
        ).



      "--------------------------------------------------------
      " Update item status
      "--------------------------------------------------------

      MODIFY ENTITIES OF ZI_PO_UPLOAD1
        IN LOCAL MODE

        ENTITY _Item

        UPDATE FIELDS
        (
          Status
          Message
        )

        WITH VALUE #(

          FOR ls_failed_item IN lt_items

          (
            %tky =
              ls_failed_item-%tky

            Status =
              'ERROR'

            Message =
              lv_message
          )

        ).



      "--------------------------------------------------------
      " Return error state to UI
      "--------------------------------------------------------

      READ ENTITIES OF ZI_PO_UPLOAD1
        IN LOCAL MODE

        ENTITY Upload

        ALL FIELDS

        WITH CORRESPONDING #( keys )

        RESULT DATA(lt_failed_result).


      result =
        VALUE #(

          FOR ls_failed IN lt_failed_result

          (
            %tky =
              ls_failed-%tky

            %param =
              ls_failed
          )

        ).


      RETURN.

    ENDIF.

 "==========================================================
" STEP 10 : STORE PO %PID FOR FINAL PO NUMBER
"==========================================================

zbp_i_po_upload1=>gt_po_mapped = po_mapped.

LOOP AT po_mapped-purchaseorder
  ASSIGNING FIELD-SYMBOL(<ls_po_map>).

  APPEND VALUE #(
    cid         = <ls_po_map>-%cid
    upload_uuid = ls_header-UploadUUID
  ) TO zbp_i_po_upload1=>gt_po_link.

ENDLOOP.


"==========================================================
" STEP 11 : UPDATE ROOT AS SUBMITTED
"==========================================================

MODIFY ENTITIES OF ZI_PO_UPLOAD1
  IN LOCAL MODE

  ENTITY Upload

  UPDATE FIELDS
  (
    Status
    Success
    Failed
    Message
  )

  WITH VALUE #(
    (
      %tky =
        keys[ 1 ]-%tky

      Status =
        'SUBMITTED'

      Success =
        lines( lt_items )

      Failed =
        0

      Message =
        'Purchase Order submitted successfully.'
    )
  ).


"==========================================================
" STEP 12 : UPDATE ITEMS AS SUBMITTED
"==========================================================

MODIFY ENTITIES OF ZI_PO_UPLOAD1
  IN LOCAL MODE

  ENTITY _Item

  UPDATE FIELDS
  (
    Status
    Message
  )

  WITH VALUE #(

    FOR ls_success_item IN lt_items

    (
      %tky =
        ls_success_item-%tky

      Status =
        'SUBMITTED'

      Message =
        'PO item submitted successfully'
    )

  ).




        "==========================================================
        " STEP 14 : RETURN UPDATED ROOT
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          ALL FIELDS

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_final_result).


        result =
          VALUE #(

            FOR ls_final IN lt_final_result

            (
              %tky =
                ls_final-%tky

              %param =
                ls_final
            )

          ).


      ENDMETHOD.


      "#################################################################
      "#
      "# DETERMINATION : AUTO PROCESS EXCEL ON CREATE/SAVE
      "#
      "#################################################################

      METHOD autouploadoncreate.


        "==========================================================
        " STEP 1 : CHECK WHETHER EXCEL FILE EXISTS
        "==========================================================

        READ ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          FIELDS
          (
            Attachment
            FileName
            MimeType
          )

          WITH CORRESPONDING #( keys )

          RESULT DATA(lt_upload).


        IF lt_upload IS INITIAL.
          RETURN.
        ENDIF.


        DATA(ls_upload) = lt_upload[ 1 ].


        "==========================================================
        " STEP 2 : DO NOTHING IF FILE NOT SELECTED
        "==========================================================

        IF ls_upload-Attachment IS INITIAL.
          RETURN.
        ENDIF.


        "==========================================================
        " STEP 3 : AUTOMATICALLY EXECUTE EXISTING UPLOAD EXCEL
        "==========================================================

        MODIFY ENTITIES OF ZI_PO_UPLOAD1
          IN LOCAL MODE

          ENTITY Upload

          EXECUTE UploadExcel

          FROM VALUE #(
            FOR ls_key IN keys
            (
              %tky = ls_key-%tky
            )
          )

          FAILED DATA(lt_failed)
          REPORTED DATA(lt_reported).


        "==========================================================
        " STEP 4 : PASS MESSAGES BACK TO FIORI
        "==========================================================

        reported =
          CORRESPONDING #( DEEP lt_reported ).


      ENDMETHOD.


    ENDCLASS.

"============================================================
" SAVER CLASS DEFINITION
"============================================================

CLASS lsc_zi_po_upload1 DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.



"============================================================
" SAVER CLASS IMPLEMENTATION
"============================================================

CLASS lsc_zi_po_upload1 IMPLEMENTATION.


  METHOD save_modified.


    "----------------------------------------------------------
    " Check whether standard PO creation returned mapping
    "----------------------------------------------------------
    IF zbp_i_po_upload1=>gt_po_mapped-purchaseorder
         IS INITIAL.

      RETURN.

    ENDIF.


    LOOP AT zbp_i_po_upload1=>gt_po_mapped-purchaseorder
      ASSIGNING FIELD-SYMBOL(<ls_mapped_po>).


      "========================================================
      " GET FINAL PO NUMBER FROM %PID
      "========================================================

      CONVERT KEY OF I_PurchaseOrderTP_2

        FROM <ls_mapped_po>-%pid

        TO DATA(ls_po_key).


      IF ls_po_key-PurchaseOrder IS INITIAL.

        CONTINUE.

      ENDIF.


      "========================================================
      " FIND UPLOAD UUID
      "========================================================

      READ TABLE zbp_i_po_upload1=>gt_po_link

        WITH KEY
          cid = <ls_mapped_po>-%cid

        INTO DATA(ls_link).


      IF sy-subrc <> 0.

        CONTINUE.

      ENDIF.


      "========================================================
      " UPDATE HEADER WITH FINAL PO NUMBER
      "========================================================

      UPDATE zpo_up_h1

        SET po_number =
              @ls_po_key-PurchaseOrder,

            status =
              'CREATED',

            message =
              'Purchase Order created successfully.'

        WHERE upload_uuid =
              @ls_link-upload_uuid.


      "========================================================
      " UPDATE ITEM WITH FINAL PO NUMBER
      "========================================================

      UPDATE zpo_up_i1

        SET po_number =
              @ls_po_key-PurchaseOrder,

            status =
              'CREATED',

            message =
              'Purchase Order created successfully.'

        WHERE upload_uuid =
              @ls_link-upload_uuid.


    ENDLOOP.


    "----------------------------------------------------------
    " Clear temporary mapping
    "----------------------------------------------------------

    CLEAR:
      zbp_i_po_upload1=>gt_po_mapped,
      zbp_i_po_upload1=>gt_po_link.


  ENDMETHOD.


ENDCLASS.
