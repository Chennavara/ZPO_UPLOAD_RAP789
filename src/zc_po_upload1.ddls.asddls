@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload'
@Metadata.allowExtensions: true

define root view entity ZC_PO_UPLOAD1
  provider contract transactional_query
  as projection on ZI_PO_UPLOAD1

{
  key UploadUUID,

      Attachment,
      FileName,
      MimeType,

      PurchaseOrderType,
      CompanyCode,
      PurchasingOrganization,
      PurchasingGroup,
      Supplier,
      PurchaseOrderDate,
      DocumentCurrency,

      PONumber,

      TotalRows,
      Success,
      Failed,

      Status,
      Message,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,
           

      _Items :
        redirected to composition child ZC_PO_UPLOAD_ITEM1

}
