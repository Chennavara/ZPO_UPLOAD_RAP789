@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Items'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_PO_UPLOAD_ITEM1
  as select from zpo_up_i1

  association to parent ZI_PO_UPLOAD1 as _Upload
    on $projection.UploadUUID = _Upload.UploadUUID

{

  key item_uuid
        as ItemUUID,

      upload_uuid
        as UploadUUID,

      row_no
        as RowNo,

      purchase_order_item
        as PurchaseOrderItem,

      material
        as Material,

      item_text
        as ItemText,

      material_group
        as MaterialGroup,

      plant
        as Plant,


     // @Semantics.quantity.unitOfMeasure: 'UOM'
      quantity
        as Quantity,

      //@Semantics.unitOfMeasure: true
      uom
        as UOM,


      @Semantics.amount.currencyCode: 'Currency'
      net_price
        as NetPrice,

      //@Semantics.currencyCode: true
      currency
        as Currency,

      tax_code
        as TaxCode,

      po_number
        as PONumber,

      status
        as Status,

      message
        as Message,

      _Upload

}
