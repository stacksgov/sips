;; token-metadata-update-notify
;;
;; Use this contract to notify token metadata indexers that an NFT or FT needs its metadata
;; refreshed.

(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Refresh the metadata for one or more NFTs from a specific contract.
(define-public (nft-metadata-update-notify (contract <nft-trait>) (token-ids (list 100 uint)))
  (ok (print
    {
      notification: "token-metadata-update",
      payload: {
        contract-id: contract,
        token-class: "nft",
        token-ids: token-ids
      }
    })))

;; Refresh the metadata for a FT from a specific contract
(define-public (ft-metadata-update-notify (contract <ft-trait>))
  (ok (print
    {
      notification: "token-metadata-update",
      payload: {
        contract-id: contract,
        token-class: "ft"
      }
    })))
