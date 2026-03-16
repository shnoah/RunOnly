import SwiftUI

// 앱의 메인 탭 구조를 구성하고 공통 상태 객체를 각 탭에 주입한다.
struct ContentView: View {
    @StateObject private var viewModel = RunningWorkoutsViewModel()
    @StateObject private var shoeStore = ShoeStore()
    @StateObject private var appSettings = AppSettingsStore()
    @StateObject private var mileageGoalStore = MileageGoalStore()

    var body: some View {
        TabView {
            HomeTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .environmentObject(mileageGoalStore)
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            RecordTabView(viewModel: viewModel)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("기록", systemImage: "list.bullet.rectangle")
                }

            ShoesTabView(runs: viewModel.allRuns)
                .environmentObject(shoeStore)
                .tabItem {
                    Label("신발", systemImage: "shoeprints.fill")
                }

            SettingsTabView()
                .environmentObject(shoeStore)
                .environmentObject(appSettings)
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
        .environmentObject(viewModel)
        .tint(Color(red: 0.29, green: 0.88, blue: 0.63))
        .onAppear {
            viewModel.showAppleWorkoutOnly = appSettings.defaultAppleOnlyFilter
        }
        .onChange(of: appSettings.defaultAppleOnlyFilter) {
            viewModel.showAppleWorkoutOnly = appSettings.defaultAppleOnlyFilter
            viewModel.applyFilter()
        }
    }
}

// 미리보기는 앱 루트 화면만 빠르게 점검할 때 사용한다.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
