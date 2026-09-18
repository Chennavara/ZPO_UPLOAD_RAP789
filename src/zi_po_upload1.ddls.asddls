@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'PO Upload Root'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_PO_UPLOAD1
  as select from zpo_up_h1

  composition [0..*] of ZI_PO_UPLOAD_ITEM1 as _Items

{

  key upload_uuid
        as UploadUUID,



  @Semantics.largeObject: {
    mimeType: 'MimeType',
    fileName: 'FileName',
    contentDispositionPreference: #ATTACHMENT
  }
  attachment
        as Attachment,


  file_name
        as FileName,


  @Semantics.mimeType: true
  
  mime_type
        as MimeType,


 

  purchase_order_type
        as PurchaseOrderType,

  company_code
        as CompanyCode,

  purchasing_org
        as PurchasingOrganization,

  purchasing_group
        as PurchasingGroup,

  supplier
        as Supplier,

  purchase_order_date
        as PurchaseOrderDate,

  //@Semantics.currencyCode: true
  document_currency
        as DocumentCurrency,


 

  po_number
        as PONumber,

      
      
  total_rows
        as TotalRows,

  success
        as Success,

  failed
        as Failed,

  status
        as Status,

  message
        as Message,




  created_by
        as CreatedBy,

  created_at
        as CreatedAt,

  last_changed_by
        as LastChangedBy,

  local_last_changed_at
        as LocalLastChangedAt,


  _Items

}
