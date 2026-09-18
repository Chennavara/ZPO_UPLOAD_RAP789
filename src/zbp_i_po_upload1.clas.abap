CLASS zbp_i_po_upload1 DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_po_upload1.

  PUBLIC SECTION.

    CLASS-DATA gt_po_mapped
      TYPE RESPONSE FOR MAPPED I_PurchaseOrderTP_2.

    TYPES:
      BEGIN OF ty_po_link,
        cid         TYPE abp_behv_cid,
        upload_uuid TYPE zpo_up_h1-upload_uuid,
      END OF ty_po_link.

    CLASS-DATA gt_po_link
      TYPE STANDARD TABLE OF ty_po_link
      WITH EMPTY KEY.

ENDCLASS.


CLASS zbp_i_po_upload1 IMPLEMENTATION.
ENDCLASS.
