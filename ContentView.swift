import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Models
struct Arac: Identifiable, Codable {
    var id = UUID()
    var plaka: String
    var tip: AracTip
    
    enum AracTip: String, Codable, CaseIterable {
        case binek = "Binek"
        case ticari = "Ticari"
    }
}

struct Gider: Identifiable, Codable {
    var id = UUID()
    var aracId: UUID
    var tip: GiderTip
    var tutar: Double
    var tarih: Date
    var kdvOrani: Double
    var aciklama: String
    
    var matrah: Double {
        tutar / (1 + kdvOrani / 100)
    }
    
    var kdvTutari: Double {
        tutar - matrah
    }
    
    enum GiderTip: String, Codable, CaseIterable {
        case yakit = "⛽ Yakıt"
        case tamir = "🔧 Tamir"
        case bakim = "🛠️ Bakım"
        case otopark = "🅿️ Otopark"
        case yikama = "🚗 Yıkama"
        case lastik = "🛞 Lastik"
        case yedekParca = "🔩 Yedek Parça"
        case sigorta = "📋 Sigorta"
        case diger = "📌 Diğer"
    }
}

struct MuhasebeKayit {
    var hesap770: Double
    var hesap191: Double
    var hesap689: Double
    var hesap320: Double
}

// MARK: - View Model
class MuhasebeViewModel: ObservableObject {
    @Published var araclar = [Arac]()
    @Published var giderler = [Gider]()
    
    init() {
        loadData()
    }
    
    func aracEkle(_ arac: Arac) {
        araclar.append(arac)
        saveData()
    }
    
    func aracSil(at offsets: IndexSet) {
        araclar.remove(atOffsets: offsets)
        saveData()
    }
    
    func giderEkle(_ gider: Gider) {
        giderler.append(gider)
        saveData()
    }
    
    func giderSil(at offsets: IndexSet) {
        giderler.remove(atOffsets: offsets)
        saveData()
    }
    
    func muhasebeKaydiHesapla(gider: Gider, arac: Arac) -> MuhasebeKayit {
        let matrah = gider.matrah
        
        if arac.tip == .binek {
            let x = matrah * 0.70
            let kdv191 = (x * (1 + gider.kdvOrani / 100)) - x
            let kalan689 = matrah - x
            let kdv689 = (kalan689 * (1 + gider.kdvOrani / 100)) - kalan689
            
            return MuhasebeKayit(
                hesap770: x,
                hesap191: kdv191,
                hesap689: kalan689 + kdv689,
                hesap320: gider.tutar
            )
        } else {
            return MuhasebeKayit(
                hesap770: matrah,
                hesap191: gider.kdvTutari,
                hesap689: 0,
                hesap320: gider.tutar
            )
        }
    }
    
    func aracBul(id: UUID) -> Arac? {
        araclar.first { $0.id == id }
    }
    
    func aracGiderleri(aracId: UUID) -> [Gider] {
        giderler.filter { $0.aracId == aracId }
    }
    
    // MARK: - PDF Export
    func pdfOlustur(gider: Gider, arac: Arac) -> String {
        let kayit = muhasebeKaydiHesapla(gider: gider, arac: arac)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var pdf = """
        MUHASEBE FİŞİ
        
        Tarih: \(dateFormatter.string(from: gider.tarih))
        Araç: \(arac.plaka) (\(arac.tip.rawValue))
        Gider Tipi: \(gider.tip.rawValue)
        Toplam Tutar: \(String(format: "%.2f", gider.tutar)) TL
        KDV Oranı: %\(String(format: "%.0f", gider.kdvOrani))
        Matrah: \(String(format: "%.2f", gider.matrah)) TL
        
        """
        
        if !gider.aciklama.isEmpty {
            pdf += "Açıklama: \(gider.aciklama)\n"
        }
        
        pdf += """
        
        ─────────────────────────────────────
        MUHASEBE KAYDI
        ─────────────────────────────────────
        
        """
        
        if kayit.hesap770 > 0 {
            pdf += "770 - Genel Yönetim Giderleri (Borç)\n"
            pdf += "     \(String(format: "%.2f", kayit.hesap770)) TL\n\n"
        }
        
        if kayit.hesap191 > 0 {
            pdf += "191 - İndirilecek KDV (Borç)\n"
            pdf += "     \(String(format: "%.2f", kayit.hesap191)) TL\n\n"
        }
        
        if kayit.hesap689 > 0 {
            pdf += "689 - K.K.E. Giderler (Borç)\n"
            pdf += "     \(String(format: "%.2f", kayit.hesap689)) TL\n\n"
        }
        
        pdf += "320 - Satıcılar (Alacak)\n"
        pdf += "     \(String(format: "%.2f", kayit.hesap320)) TL\n"
        
        return pdf
    }
    
    // MARK: - Excel Export (CSV)
    func csvOlustur() -> String {
        var csv = "Tarih,Plaka,Araç Tipi,Gider Tipi,Tutar,KDV Oranı,Matrah,770,191,689,320,Açıklama\n"
        
        for gider in giderler.sorted(by: { $0.tarih > $1.tarih }) {
            guard let arac = aracBul(id: gider.aracId) else { continue }
            let kayit = muhasebeKaydiHesapla(gider: gider, arac: arac)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            csv += "\(dateFormatter.string(from: gider.tarih)),"
            csv += "\(arac.plaka),"
            csv += "\(arac.tip.rawValue),"
            csv += "\(gider.tip.rawValue),"
            csv += "\(String(format: "%.2f", gider.tutar)),"
            csv += "\(String(format: "%.0f", gider.kdvOrani)),"
            csv += "\(String(format: "%.2f", gider.matrah)),"
            csv += "\(String(format: "%.2f", kayit.hesap770)),"
            csv += "\(String(format: "%.2f", kayit.hesap191)),"
            csv += "\(String(format: "%.2f", kayit.hesap689)),"
            csv += "\(String(format: "%.2f", kayit.hesap320)),"
            csv += "\"\(gider.aciklama)\"\n"
        }
        
        return csv
    }
    
    // MARK: - Persistence
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(araclar) {
            UserDefaults.standard.set(encoded, forKey: "araclar")
        }
        if let encoded = try? JSONEncoder().encode(giderler) {
            UserDefaults.standard.set(encoded, forKey: "giderler")
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "araclar"),
           let decoded = try? JSONDecoder().decode([Arac].self, from: data) {
            araclar = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "giderler"),
           let decoded = try? JSONDecoder().decode([Gider].self, from: data) {
            giderler = decoded
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var viewModel = MuhasebeViewModel()
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AracListView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Araçlar", systemImage: "car.2.fill")
                }
                .tag(0)
            
            HesaplamaView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Hesaplama", systemImage: "calculator.fill")
                }
                .tag(1)
            
            RaporlarView()
                .environmentObject(viewModel)
                .tabItem {
                    Label("Raporlar", systemImage: "chart.bar.doc.horizontal.fill")
                }
                .tag(2)
        }
    }
}

// MARK: - Araç List View
struct AracListView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    @State private var showingAddArac = false
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.araclar.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Henüz araç eklenmemiş")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Sağ üstteki + butonuna basarak araç ekleyin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    ForEach(viewModel.araclar) { arac in
                        NavigationLink(destination: AracDetayView(arac: arac)) {
                            HStack(spacing: 15) {
                                Image(systemName: arac.tip == .binek ? "car.fill" : "truck.box.fill")
                                    .font(.title2)
                                    .foregroundColor(arac.tip == .binek ? .blue : .orange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(arac.plaka)
                                        .font(.headline)
                                    Text(arac.tip.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                let giderSayisi = viewModel.aracGiderleri(aracId: arac.id).count
                                if giderSayisi > 0 {
                                    Text("\(giderSayisi) gider")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .onDelete(perform: viewModel.aracSil)
                }
            }
            .navigationTitle("Araç Filosu")
            .toolbar {
                Button(action: { showingAddArac = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
            .sheet(isPresented: $showingAddArac) {
                AracEkleView()
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Araç Detay View
struct AracDetayView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    let arac: Arac
    
    var aracGiderleri: [Gider] {
        viewModel.aracGiderleri(aracId: arac.id).sorted(by: { $0.tarih > $1.tarih })
    }
    
    var toplamTutar: Double {
        aracGiderleri.reduce(0) { $0 + $1.tutar }
    }
    
    var body: some View {
        List {
            Section(header: Text("Araç Bilgileri")) {
                HStack {
                    Text("Plaka")
                    Spacer()
                    Text(arac.plaka)
                        .bold()
                }
                HStack {
                    Text("Araç Tipi")
                    Spacer()
                    Text(arac.tip.rawValue)
                        .bold()
                }
                HStack {
                    Text("Toplam Gider")
                    Spacer()
                    Text("\(aracGiderleri.count) kayıt")
                        .bold()
                }
                HStack {
                    Text("Toplam Tutar")
                    Spacer()
                    Text("\(String(format: "%.2f", toplamTutar)) TL")
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            
            if !aracGiderleri.isEmpty {
                Section(header: Text("Gider Geçmişi")) {
                    ForEach(aracGiderleri) { gider in
                        NavigationLink(destination: GiderDetayView(gider: gider)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(gider.tip.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(String(format: "%.2f", gider.tutar)) TL")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                Text(gider.tarih, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(arac.plaka)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Araç Ekle View
struct AracEkleView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var plaka = ""
    @State private var seciliTip: Arac.AracTip = .binek
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Araç Bilgileri")) {
                    TextField("Plaka (örn: 34ABC123)", text: $plaka)
                        .textInputAutocapitalization(.characters)
                    
                    Picker("Araç Tipi", selection: $seciliTip) {
                        ForEach(Arac.AracTip.allCases, id: \.self) { tip in
                            HStack {
                                Image(systemName: tip == .binek ? "car.fill" : "truck.box.fill")
                                Text(tip.rawValue)
                            }
                            .tag(tip)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ℹ️ Bilgi")
                            .font(.subheadline)
                            .bold()
                        Text("Binek araçlarda giderlerin %70'i gider yazılır, %30'u kanunen kabul edilmeyen gider olarak kaydedilir.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Yeni Araç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        let arac = Arac(plaka: plaka.uppercased(), tip: seciliTip)
                        viewModel.aracEkle(arac)
                        dismiss()
                    }
                    .disabled(plaka.isEmpty)
                }
            }
        }
    }
}

// MARK: - Hesaplama View (Ana Gider Ekleme)
struct HesaplamaView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    @State private var showingAddGider = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.giderler.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calculator.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Gider Hesaplaması")
                            .font(.title2)
                            .bold()
                        Text("Araç giderlerinizi ekleyin ve otomatik muhasebe kaydı oluşturun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            if viewModel.araclar.isEmpty {
                                // Uyarı göster
                            } else {
                                showingAddGider = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Gider Ekle")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(viewModel.araclar.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.araclar.isEmpty)
                        
                        if viewModel.araclar.isEmpty {
                            Text("⚠️ Önce Araçlar sekmesinden araç ekleyin")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.giderler.sorted(by: { $0.tarih > $1.tarih })) { gider in
                            NavigationLink(destination: GiderDetayView(gider: gider)) {
                                if let arac = viewModel.aracBul(id: gider.aracId) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(gider.tip.rawValue)
                                                .font(.headline)
                                            Text(arac.plaka)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(gider.tarih, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(String(format: "%.2f", gider.tutar)) TL")
                                                .font(.headline)
                                                .foregroundColor(.blue)
                                            Text(arac.tip.rawValue)
                                                .font(.caption)
                                                .foregroundColor(arac.tip == .binek ? .blue : .orange)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .onDelete(perform: viewModel.giderSil)
                    }
                }
            }
            .navigationTitle("Hesaplama")
            .toolbar {
                if !viewModel.giderler.isEmpty {
                    Button(action: {
                        if !viewModel.araclar.isEmpty {
                            showingAddGider = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(viewModel.araclar.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddGider) {
                GiderEkleView()
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Gider Ekle View
struct GiderEkleView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var seciliAracId: UUID?
    @State private var seciliGiderTip: Gider.GiderTip = .yakit
    @State private var tutar = ""
    @State private var tarih = Date()
    @State private var kdvOrani = 20.0
    @State private var aciklama = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gider Bilgileri")) {
                    Picker("Araç Seçin", selection: $seciliAracId) {
                        Text("Seçiniz").tag(nil as UUID?)
                        ForEach(viewModel.araclar) { arac in
                            HStack {
                                Image(systemName: arac.tip == .binek ? "car.fill" : "truck.box.fill")
                                Text("\(arac.plaka) - \(arac.tip.rawValue)")
                            }
                            .tag(arac.id as UUID?)
                        }
                    }
                    
                    Picker("Gider Tipi", selection: $seciliGiderTip) {
                        ForEach(Gider.GiderTip.allCases, id: \.self) { tip in
                            Text(tip.rawValue).tag(tip)
                        }
                    }
                    
                    TextField("Tutar (KDV Dahil)", text: $tutar)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
                }
                
                Section(header: Text("KDV Bilgileri")) {
                    HStack {
                        Text("KDV Oranı")
                        Spacer()
                        Text("%\(String(format: "%.0f", kdvOrani))")
                            .foregroundColor(.blue)
                            .bold()
                    }
                    
                    HStack {
                        Text("%1")
                            .font(.caption)
                        Slider(value: $kdvOrani, in: 1...20, step: 1)
                        Text("%20")
                            .font(.caption)
                    }
                    
                    // Önizleme
                    if let tutarDouble = Double(tutar.replacingOccurrences(of: ",", with: ".")),
                       tutarDouble > 0,
                       let aracId = seciliAracId,
                       let arac = viewModel.aracBul(id: aracId) {
                        let tempGider = Gider(aracId: aracId, tip: seciliGiderTip, tutar: tutarDouble, tarih: tarih, kdvOrani: kdvOrani, aciklama: "")
                        let kayit = viewModel.muhasebeKaydiHesapla(gider: tempGider, arac: arac)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ön İzleme")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Matrah:")
                                Spacer()
                                Text("\(String(format: "%.2f", tempGider.matrah)) TL")
                            }
                            .font(.caption)
                            
                            if arac.tip == .binek {
                                HStack {
                                    Text("770 (Gider):")
                                    Spacer()
                                    Text("\(String(format: "%.2f", kayit.hesap770)) TL")
                                        .foregroundColor(.green)
                                }
                                .font(.caption)
                                
                                HStack {
                                    Text("689 (K.K.E.):")
                                    Spacer()
                                    Text("\(String(format: "%.2f", kayit.hesap689)) TL")
                                        .foregroundColor(.orange)
                                }
                                .font(.caption)
                            } else {
                                HStack {
                                    Text("770 (Tüm Gider):")
                                    Spacer()
                                    Text("\(String(format: "%.2f", kayit.hesap770)) TL")
                                        .foregroundColor(.green)
                                }
                                .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Ek Bilgiler (Opsiyonel)")) {
                    TextField("Açıklama", text: $aciklama)
                }
            }
            .navigationTitle("Yeni Gider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if let aracId = seciliAracId,
                           let tutarDouble = Double(tutar.replacingOccurrences(of: ",", with: ".")) {
                            let gider = Gider(
                                aracId: aracId,
                                tip: seciliGiderTip,
                                tutar: tutarDouble,
                                tarih: tarih,
                                kdvOrani: kdvOrani,
                                aciklama: aciklama
                            )
                            viewModel.giderEkle(gider)
                            dismiss()
                        }
                    }
                    .disabled(seciliAracId == nil || tutar.isEmpty)
                }
            }
        }
    }
}

// MARK: - Gider Detay View
struct GiderDetayView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    let gider: Gider
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        if let arac = viewModel.aracBul(id: gider.aracId) {
            let kayit = viewModel.muhasebeKaydiHesapla(gider: gider, arac: arac)
            
            List {
                Section(header: Text("Genel Bilgiler")) {
                    HStack {
                        Text("Gider Tipi")
                        Spacer()
                        Text(gider.tip.rawValue)
                            .bold()
                    }
                    HStack {
                        Text("Araç")
                        Spacer()
                        Text("\(arac.plaka) (\(arac.tip.rawValue))")
                    }
                    HStack {
                        Text("Tarih")
                        Spacer()
                        Text(gider.tarih, style: .date)
                    }
                    if !gider.aciklama.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Açıklama")
                                .foregroundColor(.gray)
                            Text(gider.aciklama)
                        }
                    }
                }
                
                Section(header: Text("Tutar Bilgileri")) {
                    HStack {
                        Text("Toplam Tutar")
                        Spacer()
                        Text("\(String(format: "%.2f", gider.tutar)) TL")
                            .bold()
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("KDV Oranı")
                        Spacer()
                        Text("%\(String(format: "%.0f", gider.kdvOrani))")
                    }
                    HStack {
                        Text("Matrah (KDV Hariç)")
                        Spacer()
                        Text("\(String(format: "%.2f", gider.matrah)) TL")
                    }
                    HStack {
                        Text("KDV Tutarı")
                        Spacer()
                        Text("\(String(format: "%.2f", gider.kdvTutari)) TL")
                    }
                }
                
                Section(header: Text("Muhasebe Kaydı")) {
                    if kayit.hesap770 > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("770 - Genel Yönetim Giderleri")
                                .font(.subheadline)
                            HStack {
                                Text("Borç")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(String(format: "%.2f", kayit.hesap770)) TL")
                                    .bold()
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if kayit.hesap191 > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("191 - İndirilecek KDV")
                                .font(.subheadline)
                            HStack {
                                Text("Borç")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(String(format: "%.2f", kayit.hesap191)) TL")
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if kayit.hesap689 > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("689 - K.K.E. Giderler")
                                .font(.subheadline)
                            HStack {
                                Text("Borç")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(String(format: "%.2f", kayit.hesap689)) TL")
                                    .bold()
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("320 - Satıcılar")
                            .font(.subheadline)
                        HStack {
                            Text("Alacak")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(String(format: "%.2f", kayit.hesap320)) TL")
                                .bold()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(action: {
                        shareText = viewModel.pdfOlustur(gider: gider, arac: arac)
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Muhasebe Fişini Paylaş")
                        }
                    }
                }
            }
            .navigationTitle("Gider Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }
}

// MARK: - Raporlar View
struct RaporlarView: View {
    @EnvironmentObject var viewModel: MuhasebeViewModel
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var selectedAracFilter: UUID?
    @State private var selectedGiderTipFilter: Gider.GiderTip?
    
    var filteredGiderler: [Gider] {
        var result = viewModel.giderler
        
        if let aracId = selectedAracFilter {
            result = result.filter { $0.aracId == aracId }
        }
        
        if let giderTip = selectedGiderTipFilter {
            result = result.filter { $0.tip == giderTip }
        }
        
        return result
    }
    
    var toplamTutar: Double {
        filteredGiderler.reduce(0) { $0 + $1.tutar }
    }
    
    var toplam770: Double {
        filteredGiderler.reduce(0.0) { toplam, gider in
            guard let arac = viewModel.aracBul(id: gider.aracId) else { return toplam }
            let kayit = viewModel.muhasebeKaydiHesapla(gider: gider, arac: arac)
            return toplam + kayit.hesap770
        }
    }
    
    var toplam191: Double {
        filteredGiderler.reduce(0.0) { toplam, gider in
            guard let arac = viewModel.aracBul(id: gider.aracId) else { return toplam }
            let kayit = viewModel.muhasebeKaydiHesapla(gider: gider, arac: arac)
            return toplam + kayit.hesap191
        }
    }
    
    var toplam689: Double {
        filteredGiderler.reduce(0.0) { toplam, gider in
            guard let arac = viewModel.aracBul(id: gider.aracId) else { return toplam }
            let kayit = viewModel.muhasebeKaydiHesapla(gider: gider, arac: arac)
            return toplam + kayit.hesap689
        }
    }
    
    var giderTipiDagilim: [(tip: Gider.GiderTip, tutar: Double, adet: Int)] {
        let grouped = Dictionary(grouping: filteredGiderler, by: { $0.tip })
        return grouped.map { (tip, giderler) in
            let tutar = giderler.reduce(0) { $0 + $1.tutar }
            return (tip, tutar, giderler.count)
        }.sorted { $0.tutar > $1.tutar }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Filtreler")) {
                    Picker("Araç Filtresi", selection: $selectedAracFilter) {
                        Text("Tüm Araçlar").tag(nil as UUID?)
                        ForEach(viewModel.araclar) { arac in
                            Text(arac.plaka).tag(arac.id as UUID?)
                        }
                    }
                    
                    Picker("Gider Tipi Filtresi", selection: $selectedGiderTipFilter) {
                        Text("Tüm Tipler").tag(nil as Gider.GiderTip?)
                        ForEach(Gider.GiderTip.allCases, id: \.self) { tip in
                            Text(tip.rawValue).tag(tip as Gider.GiderTip?)
                        }
                    }
                    
                    if selectedAracFilter != nil || selectedGiderTipFilter != nil {
                        Button("Filtreleri Temizle") {
                            selectedAracFilter = nil
                            selectedGiderTipFilter = nil
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Genel Özet")) {
                    HStack {
                        Text("Toplam Araç")
                        Spacer()
                        Text("\(viewModel.araclar.count)")
                            .bold()
                    }
                    HStack {
                        Text("Toplam Gider Kaydı")
                        Spacer()
                        Text("\(filteredGiderler.count)")
                            .bold()
                    }
                    HStack {
                        Text("Toplam Tutar")
                        Spacer()
                        Text("\(String(format: "%.2f", toplamTutar)) TL")
                            .bold()
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Muhasebe Hesap Toplamları")) {
                    HStack {
                        Text("770 - Genel Yönetim")
                        Spacer()
                        Text("\(String(format: "%.2f", toplam770)) TL")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("191 - İndirilecek KDV")
                        Spacer()
                        Text("\(String(format: "%.2f", toplam191)) TL")
                            .foregroundColor(.blue)
                    }
                    if toplam689 > 0 {
                        HStack {
                            Text("689 - K.K.E. Giderler")
                            Spacer()
                            Text("\(String(format: "%.2f", toplam689)) TL")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                if !giderTipiDagilim.isEmpty {
                    Section(header: Text("Gider Tipi Dağılımı")) {
                        ForEach(giderTipiDagilim, id: \.tip) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.tip.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(item.adet) adet")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                HStack {
                                    Text("Toplam:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(String(format: "%.2f", item.tutar)) TL")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section(header: Text("Dışa Aktar")) {
                    Button(action: {
                        shareText = viewModel.csvOlustur()
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "tablecells")
                            Text("Excel (CSV) Olarak Aktar")
                            Spacer()
                            Image(systemName: "arrow.down.doc")
                        }
                    }
                    .disabled(viewModel.giderler.isEmpty)
                }
            }
            .navigationTitle("Raporlar")
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareText])
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - App Entry Point
@main
struct OtomatikMuhasebeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
