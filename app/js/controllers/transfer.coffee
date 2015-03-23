angular.module("app").controller "TransferController", ($scope, $stateParams, $modal, $q, $filter, Wallet, WalletAPI, Blockchain, BlockchainAPI, Utils, Info, Growl, Observer) ->
    Info.refresh_info()
    $scope.utils = Utils
    $scope.balances = null
    $scope.currencies = null
    $scope.show_from_section = true
    $scope.account_from_name = account_from_name = $stateParams.from
    $scope.gravatar_account_name = null
    $scope.address_type = "account"
    $scope.refreshing_balances = true

    pubkey_regexp = new RegExp("^#{Info.info.address_prefix}[a-zA-Z0-9]+")

    $scope.memo_size_max = 51
    my_transfer_form = null
    tx_fee = null
    $scope.tx_fee_asset = null
    $scope.no_account = false
    $scope.model ||= {}
    $scope.add_to_address_book = {}

    $scope.transfer_info =
        amount : $stateParams.amount
        symbol: $stateParams.asset
        payto : $stateParams.to
        memo :  $stateParams.memo
        show_vote_options: Wallet.default_vote == "vote_per_transfer"
        vote : if Wallet.default_vote == "vote_per_transfer" then "vote_all" else Wallet.default_vote
        unknown_account: false

    $scope.vote_options =
        vote_none: "vote_none"
        vote_all: "vote_all"
        vote_random: "vote_random_subset"
        vote_recommended: "vote_as_delegates_recommended"

    $scope.my_accounts = []
    $scope.accounts = null

    $scope.$watchCollection ->
        Wallet.accounts
    , ->
        return unless Wallet.accounts
        $scope.accounts = Wallet.accounts
        $scope.my_accounts.splice(0, $scope.my_accounts.length)
        for k,a of Wallet.accounts
            if a.is_my_account
                $scope.my_accounts.push a

    account_balances_observer =
        name: "account_balances_observer"
        frequency: "each_block"
        update: (data, deferred) ->
            Wallet.refresh_account($scope.account_from_name).then ->
                $scope.balances = Wallet.balances[$scope.account_from_name]
                $scope.currencies = if $scope.balances then Object.keys($scope.balances) else []
                $scope.currencies.unshift("") if  $scope.currencies.length > 1
                unless $scope.transfer_info.symbol
                    $scope.transfer_info.symbol = if $scope.currencies.length then $scope.currencies[0] else ""
                $scope.refreshing_balances = false
                $scope.payToChanged()
                deferred.resolve(true)
            , (error) ->
                $scope.refreshing_balances = false
                deferred.reject(false)
    Observer.registerObserver(account_balances_observer)

    $scope.$on "$destroy", ->
        Observer.unregisterObserver(account_balances_observer)


    Blockchain.get_info().then (config) ->
        $scope.memo_size_max = config.memo_size_max
    
    $scope.setForm = (form) ->
        my_transfer_form = form
    
    # Validation and display prior to form submit
    $scope.hot_check_send_amount = ->
        return unless tx_fee
        return unless $scope.balances
        return unless $scope.balances[$scope.transfer_info.symbol]
        return unless my_transfer_form.amount
        
        my_transfer_form.amount.error_message = null
        
        if tx_fee.asset_id != $scope.tx_fee_asset.id
            console.log "ERROR hot_check[_send_amount] encountered unlike transfer and fee assets"
            return
        
        fee=tx_fee.amount/$scope.tx_fee_asset.precision
        transfer_amount=$scope.transfer_info.amount
        _bal=$scope.balances[$scope.transfer_info.symbol]
        balance = _bal.amount/_bal.precision
        balance_after_transfer = balance - transfer_amount
        #display "New Balance 999 (...)"
        $scope.transfer_asset = Blockchain.symbol2records[$scope.transfer_info.symbol]
        
        if tx_fee.asset_id is $scope.transfer_asset.id
            balance_after_transfer -= fee
        
        $scope.balance_after_transfer = balance_after_transfer
        $scope.balance = balance
        $scope.balance_precision = _bal.precision
        #transfer_amount -> already available as $scope.transfer_info.amount
        $scope.fee = fee
        
        my_transfer_form.$setValidity "funds", balance_after_transfer >= 0
        if balance_after_transfer < 0
            my_transfer_form.amount.error_message = "Insufficient funds"

    #call to initialize and on symbol change
    $scope.$watch ->
        $scope.transfer_info.symbol
    , ->
        return if not $scope.transfer_info.symbol or $scope.transfer_info.symbol == "Symbol not set"
        #Load the tx_fee and its asset object for pre form submit validation
        WalletAPI.get_transaction_fee($scope.transfer_info.symbol).then (_tx_fee) ->
            tx_fee = _tx_fee
            Blockchain.get_asset(tx_fee.asset_id).then (_tx_fee_asset) ->
                $scope.tx_fee_asset = _tx_fee_asset
                $scope.hot_check_send_amount()

    yesSend = ->
        vote = if Wallet.default_vote == "vote_per_transfer" then $scope.transfer_info.vote else Wallet.default_vote
        if $scope.address_type == "pubkey"
            transfer_promise = WalletAPI.transfer_to_address($scope.transfer_info.amount, $scope.transfer_info.symbol, account_from_name, $scope.transfer_info.payto, $scope.transfer_info.memo, vote)
        else
            transfer_promise = WalletAPI.transfer($scope.transfer_info.amount, $scope.transfer_info.symbol, account_from_name, $scope.transfer_info.payto, $scope.transfer_info.memo, vote)
        transfer_promise.then (response) ->
            $scope.transfer_info.payto = ""
            my_transfer_form.payto.$setPristine()
            $scope.transfer_info.amount = ""
            my_transfer_form.amount.$setPristine()
            $scope.transfer_info.memo = ""
            $scope.gravatar_account_name = ""
            $scope.add_to_address_book.message = ""
            Growl.notice "", "Transfer transaction broadcasted"
            $scope.model.t_active=true
        , (error) ->
            if error.data.error.code == 20005
                my_transfer_form.payto.error_message = "Unknown receive account"
            else if error.data.error.code == 20010
                my_transfer_form.amount.error_message = "Insufficient funds"
            else
                my_transfer_form.payto.error_message = Utils.formatAssertException(error.data.error.message)

    $scope.send = ->
        my_transfer_form.amount.error_message = null
        my_transfer_form.payto.error_message = null
        payto = $scope.transfer_info.payto
        $scope.address_type = if pubkey_regexp.exec(payto) then "pubkey" else "account"
        amount_asset = $scope.balances[$scope.transfer_info.symbol]
        transfer_amount = Utils.formatDecimal($scope.transfer_info.amount, amount_asset.precision)
        WalletAPI.get_transaction_fee($scope.transfer_info.symbol).then (tx_fee) ->
            transfer_asset = Blockchain.symbol2records[$scope.transfer_info.symbol]
            Blockchain.get_asset(tx_fee.asset_id).then (tx_fee_asset) ->
                transaction_fee = Utils.formatAsset(Utils.asset(tx_fee.amount, tx_fee_asset))
                trx =
                    to: payto
                    amount: transfer_amount + ' ' + $scope.transfer_info.symbol
                    fee: transaction_fee, memo: $scope.transfer_info.memo
                    vote: $scope.vote_options[$scope.transfer_info.vote]
                    is_favorite: !!Wallet.favorites[payto]
                    address_type: $scope.address_type
                $modal.open
                    templateUrl: "dialog-transfer-confirmation.html"
                    controller: "DialogTransferConfirmationController"
                    resolve:
                        trx: -> trx
                        action: -> yesSend
                        transfer_type: ->
                            if transfer_asset.id is 0 then 'xts' else ''

    $scope.newContactModal = (add_contact_mode = false) ->
        $modal.open
            templateUrl: "addressbookmodal.html"
            controller: "AddressBookModalController"
            resolve:
                contact_name: ->
                    $scope.transfer_info.payto
                add_contact_mode: ->
                    add_contact_mode
                action: ->
                    (contact)->
                        $scope.gravatar_account_name = $scope.transfer_info.payto = contact
                        $scope.add_to_address_book.error = ""
                        $scope.add_to_address_book.message = ""
                        my_transfer_form?.payto.error_message = ""

    $scope.onSelect = (name) ->
        $scope.transfer_info.payto = name
        $scope.gravatar_account_name = name

    $scope.accountSuggestions = (input) ->
        $filter('filter')(Object.keys(Wallet.favorites),input)

    $scope.addToAddressBook = () ->

        name = if $scope.gravatar_account_name && ($scope.address_type == 'pubkey') then $scope.gravatar_account_name else $scope.transfer_info.payto

        error_handler = (error) ->
            message = Utils.formatAssertException(error.data.error.message)
            $scope.add_to_address_book.error = if message and message.length > 2 then message else ""
            $scope.newContactModal(true)


        WalletAPI.account_set_favorite(name, true, error_handler).then ->
            account = Wallet.accounts[name]
            if account
                account.is_favorite = true
                Wallet.favorites[name] = account
                $scope.add_to_address_book.message = "Added to address book"
            else
                Wallet.refresh_account(name).then (account) ->
                    if account
                        account.is_favorite = true
                        Wallet.favorites[name] = account
                        $scope.add_to_address_book.message = "Added to address book"
                    else
                        $scope.add_to_address_book.error = "Unknown account"
                , (error) ->
                    $scope.add_to_address_book.error = "Unknown account"

    $scope.payToChanged = ->
        $scope.is_my_account = false
        $scope.account_registration_date = ""
        $scope.add_to_address_book.message = ""
        $scope.add_to_address_book.error = ""
        my_transfer_form?.payto.error_message = ""
        payto = $scope.transfer_info.payto
        return unless payto

        $scope.address_type = if pubkey_regexp.exec(payto) then "pubkey" else "account"

        account = Wallet.accounts[payto]
        if account
            $scope.gravatar_account_name = payto
            $scope.is_my_account = account.is_my_account
            $scope.account_registration_date = account.registration_date if account.registered
        else
            BlockchainAPI.get_account(payto).then (result) ->
                if result
                    $scope.account_registration_date = result.registration_date
                    $scope.transfer_info.unknown_account = false
                    if $scope.address_type == "pubkey"
                        $scope.gravatar_account_name = result.name
                    else
                        $scope.gravatar_account_name = payto
                else
                    $scope.gravatar_account_name = ""
                    $scope.transfer_info.unknown_account = $scope.address_type != "pubkey"
                    my_transfer_form.payto.error_message = "Unknown account" if $scope.transfer_info.unknown_account
