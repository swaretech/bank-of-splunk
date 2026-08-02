import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var homeStore = HomeStore()
    @State private var showBanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showBanner, let banner = auth.bannerMessage {
                    M3Banner(message: banner) {
                        withAnimation(AppMotion.standardSpring) {
                            showBanner = false
                        }
                        auth.clearBanner()
                    }
                    .dxaSensitiveContent()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if homeStore.isLoading && homeStore.homeData == nil {
                    ProgressView("Loading account…")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let data = homeStore.homeData {
                    overviewSection(data)
                        .transition(.opacity.combined(with: .offset(y: 8)))

                    actionCards(data)
                        .transition(.opacity.combined(with: .offset(y: 8)))

                    transactionSection(data)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                } else if let error = homeStore.errorMessage {
                    M3ErrorText(message: error)
                }
            }
            .padding()
            .animation(AppMotion.standardSpring, value: homeStore.homeData?.accountId)
        }
        .background(AppColors.surface)
        .navigationTitle(dataTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign out") {
                    BankRum.reportInteraction(
                        trackId: DXA.logoutSubmit,
                        component: DXA.accountNavComponent,
                        flow: nil
                    )
                    Task { await auth.logout() }
                }
                .font(AppTypography.labelLarge)
                .foregroundStyle(AppColors.primary)
                .dxaTrackID(DXA.logoutSubmit)
            }
        }
        .refreshable {
            await reload()
        }
        .task {
            await reload()
        }
        .onAppear {
            BankRum.trackScreen(DXA.homePage, component: DXA.pageComponent)
            if auth.bannerMessage != nil {
                showBanner = true
                scheduleBannerDismiss()
            }
        }
        .onChange(of: auth.bannerMessage) { newValue in
            if newValue != nil {
                withAnimation(AppMotion.standardSpring) {
                    showBanner = true
                }
                scheduleBannerDismiss()
            }
        }
    }

    private var dataTitle: String {
        homeStore.homeData?.bankName ?? "Bank of Splunk"
    }

    @ViewBuilder
    private func overviewSection(_ data: HomeData) -> some View {
        M3Card(title: "Checking Account") {
            VStack(alignment: .leading, spacing: 8) {
                Text(data.accountId)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.onSurfaceVariant)
                    .dxaSensitiveContent()
                Text(CurrencyFormatter.format(cents: data.balance))
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(AppColors.primary)
                    .dxaSensitiveContent()
            }
        }
    }

    @ViewBuilder
    private func actionCards(_ data: HomeData) -> some View {
        HStack(spacing: 16) {
            NavigationLink {
                DepositView(homeData: data)
            } label: {
                M3ActionTile(title: "Deposit Funds", systemImage: "arrow.down.circle.fill")
            }
            .dxaTrackID(DXA.depositOpen)
            .dxaInteraction(
                trackId: DXA.depositOpen,
                component: DXA.accountNavComponent,
                flow: DXA.depositFlow
            )

            NavigationLink {
                PaymentView(homeData: data)
            } label: {
                M3ActionTile(title: "Send Payment", systemImage: "arrow.up.circle.fill")
            }
            .dxaTrackID(DXA.paymentOpen)
            .dxaInteraction(
                trackId: DXA.paymentOpen,
                component: DXA.accountNavComponent,
                flow: DXA.paymentFlow
            )
        }
    }

    @ViewBuilder
    private func transactionSection(_ data: HomeData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(AppTypography.titleMedium)
                    .foregroundStyle(AppColors.onSurface)
                Spacer()
                NavigationLink("See all") {
                    TransactionListView(
                        transactions: data.history,
                        accountId: data.accountId
                    )
                }
                .font(AppTypography.labelLarge)
                .foregroundStyle(AppColors.primary)
                .dxaTrackID(DXA.transactionsOpen)
                .dxaInteraction(
                    trackId: DXA.transactionsOpen,
                    component: DXA.accountNavComponent,
                    flow: nil
                )
            }

            if data.history.isEmpty {
                Text("No transactions yet.")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.onSurfaceVariant)
            } else {
                M3Card {
                    VStack(spacing: 0) {
                        ForEach(Array(data.history.prefix(5))) { transaction in
                            M3TransactionRow(transaction: transaction, accountId: data.accountId)
                            if transaction.id != data.history.prefix(5).last?.id {
                                Divider()
                                    .background(AppColors.outlineVariant)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reload() async {
        guard let token = auth.token else { return }
        await homeStore.load(token: token)
    }

    private func scheduleBannerDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(AppMotion.standardSpring) {
                showBanner = false
            }
            auth.clearBanner()
        }
    }
}
