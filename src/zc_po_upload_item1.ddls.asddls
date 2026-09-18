@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Items'
@Metadata.allowExtensions: true

define view entity ZC_PO_UPLOAD_ITEM1
  as projection on ZI_PO_UPLOAD_ITEM1

{
  key ItemUUID,

      UploadUUID,

      RowNo,
      PurchaseOrderItem,

      Material,
      ItemText,
      MaterialGroup,

      Plant,

      Quantity,
      UOM,

      NetPrice,
      Currency,

      TaxCode,

      PONumber,

      Status,
      Message,

      _Upload :
        redirected to parent ZC_PO_UPLOAD1
}
