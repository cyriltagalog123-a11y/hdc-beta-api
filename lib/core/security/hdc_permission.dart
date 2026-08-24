enum HDCPermission {
  requestCreate,
  requestReadOwn,
  requestEditOwn,
  requestCancelOwn,

  proposalCreate,
  proposalReadOwn,
  proposalAcceptOwnRequest,

  transactionReadOwn,
  transactionUpdateOwn,
  transactionCompleteOwn,

  privateMessageReadOwnTransaction,
  privateMessageSendOwnTransaction,

  marketplaceBrowse,
  marketplaceSell,

  roleApplicationSubmit,

  businessManageOwn,
  storeManageOwn,

  adminRead,
  adminManageAccounts,
  internalRoleApplicationsReview,
  internalStructureManage,
  communityModerate,
  superAdmin,
}
