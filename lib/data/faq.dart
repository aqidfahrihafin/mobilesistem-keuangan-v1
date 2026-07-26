class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class FaqSection {
  final String title;
  final List<FaqItem> items;

  const FaqSection({required this.title, required this.items});
}

const faqSections = <FaqSection>[
  FaqSection(
    title: 'Saldo & Top Up',
    items: [
      FaqItem(
        question: 'Bagaimana cara top up saldo santri?',
        answer:
            'Buka tombol "Top Up" di halaman utama, masukkan nominal, lalu pilih metode transfer bank (VA) atau QRIS. Seluruh nominal top up langsung masuk 100% ke saldo santri, tanpa potongan apa pun.',
      ),
      FaqItem(
        question: 'Kenapa ada batas minimum saldo?',
        answer:
            'Pondok menetapkan batas minimum saldo yang harus disisakan saat membayar tagihan dari saldo, agar santri tetap punya dana untuk kebutuhan sehari-hari. Batas ini bisa dilihat di halaman Beranda pada info saldo.',
      ),
    ],
  ),
  FaqSection(
    title: 'Transfer Saldo',
    items: [
      FaqItem(
        question: 'Apa itu fitur Transfer Saldo?',
        answer:
            'Transfer Saldo memindahkan saldo secara langsung dari satu santri ke santri lain, tanpa melalui bendahara. Buka tombol "Transfer" di halaman utama, pilih santri penerima, masukkan nominal, lalu konfirmasi dengan PIN Transaksi.',
      ),
      FaqItem(
        question: 'Santri mana saja yang bisa menjadi penerima transfer?',
        answer:
            'Hanya santri yang terdaftar dalam satu Kartu Keluarga (KK) yang sama dengan santri pengirim. Ini berlaku otomatis dari data KK di sistem - jika santri yang dituju tidak muncul di daftar penerima, kemungkinan data KK keduanya belum tercatat sama dan perlu dikonfirmasi ke pengurus pondok.',
      ),
      FaqItem(
        question: 'Apakah transfer saldo perlu persetujuan admin/pondok dulu?',
        answer:
            'Tidak. Karena dana tetap berada di lingkungan pondok (hanya berpindah antar santri, tidak ditarik keluar), transfer langsung berhasil begitu PIN Transaksi dikonfirmasi - tanpa menunggu persetujuan.',
      ),
      FaqItem(
        question: 'Ke mana saya bisa melihat riwayat transfer yang sudah dilakukan?',
        answer:
            'Transfer tercatat di riwayat kedua santri (pengirim dan penerima) pada menu Laporan, dengan jenis transaksi "Transfer Antar Santri".',
      ),
    ],
  ),
  FaqSection(
    title: 'Tagihan & Pembayaran',
    items: [
      FaqItem(
        question: 'Apa bedanya bayar dari saldo dan bayar via VA/QRIS?',
        answer:
            'Bayar dari saldo memotong saldo santri yang sudah tersedia (tunduk pada batas minimum saldo). Bayar via VA/QRIS langsung ke penyedia pembayaran untuk nominal tagihan tersebut saja, dan tidak memotong ataupun mengubah saldo santri.',
      ),
      FaqItem(
        question: 'Bisakah tagihan dibayar bertahap (dicicil)?',
        answer:
            'Bisa, untuk jenis tagihan yang memang mengizinkan cicilan. Saat membayar dari saldo, Anda bisa memasukkan nominal sebagian; sisa tagihan akan tetap tercatat sampai lunas.',
      ),
      FaqItem(
        question: 'Bagaimana cara mendapatkan kwitansi pembayaran?',
        answer:
            'Buka detail tagihan yang sudah ada pembayarannya, lalu pilih cetak/unduh kwitansi. Kwitansi memiliki nomor resmi dan bisa disimpan sebagai PDF.',
      ),
    ],
  ),
  FaqSection(
    title: 'Keamanan Akun',
    items: [
      FaqItem(
        question: 'Bagaimana cara mengaktifkan login dengan sidik jari?',
        answer:
            'Buka Profil, aktifkan "Login dengan Sidik Jari", lalu verifikasi sidik jari Anda satu kali untuk mengonfirmasi. Setelah aktif, tombol sidik jari akan muncul di halaman login.',
      ),
      FaqItem(
        question: 'Kenapa aplikasi meminta verifikasi lagi setelah beberapa saat?',
        answer:
            'Untuk keamanan, sesi akan terkunci otomatis setelah beberapa menit tidak ada aktivitas. Jika login sidik jari aktif, cukup verifikasi sidik jari untuk melanjutkan; jika tidak, Anda perlu masuk ulang dengan kata sandi.',
      ),
      FaqItem(
        question: 'Lupa kata sandi, bagaimana cara resetnya?',
        answer:
            'Saat ini reset kata sandi mandiri belum tersedia di aplikasi. Silakan hubungi pengurus pondok untuk dibantu mengatur ulang kata sandi akun Anda.',
      ),
      FaqItem(
        question: 'Apa itu PIN Transaksi, dan apa bedanya dengan kata sandi?',
        answer:
            'PIN Transaksi adalah kode 6 digit terpisah dari kata sandi akun, yang diminta setiap kali membayar kantin, membayar tagihan dari saldo, atau transfer saldo ke santri lain. Tujuannya sebagai lapisan keamanan tambahan - kata sandi membuktikan Anda pemilik akun, PIN membuktikan Anda yang menyetujui transaksi saat itu, meskipun HP dalam keadaan tidak terkunci.',
      ),
      FaqItem(
        question: 'Bagaimana cara membuat atau mengubah PIN Transaksi?',
        answer:
            'Buka Profil > PIN Transaksi. Masukkan kata sandi akun Anda untuk verifikasi, lalu buat PIN 6 digit baru dan ketik ulang sebagai konfirmasi. Jika belum punya PIN, Anda juga akan diarahkan ke halaman ini secara otomatis saat pertama kali mencoba bertransaksi.',
      ),
      FaqItem(
        question: 'Lupa PIN Transaksi, bagaimana cara resetnya?',
        answer:
            'Reset PIN Transaksi mandiri belum tersedia - sama seperti kata sandi, silakan hubungi pengurus pondok untuk mengatur ulang. Setelah direset, Anda akan diminta membuat PIN baru saat transaksi berikutnya.',
      ),
      FaqItem(
        question: 'Kenapa muncul pesan "terlalu banyak percobaan" saat memasukkan PIN?',
        answer:
            'Untuk mencegah tebakan berulang, PIN akan terkunci sementara (sekitar 15 menit) setelah 5 kali salah berturut-turut. Tunggu beberapa saat lalu coba lagi, atau hubungi pengurus pondok jika Anda yakin lupa PIN-nya.',
      ),
    ],
  ),
  FaqSection(
    title: 'Riwayat & Laporan',
    items: [
      FaqItem(
        question: 'Di mana saya bisa melihat riwayat transaksi?',
        answer:
            'Buka menu Laporan di navigasi bawah - tab "Transaksi" menampilkan semua transaksi, dan tab "Pengeluaran" khusus menampilkan transaksi yang mengurangi saldo.',
      ),
      FaqItem(
        question: 'Bisakah laporan diunduh sebagai bukti/evaluasi?',
        answer:
            'Bisa. Buka tab "Laporan" di menu Laporan, pilih periode yang diinginkan, lalu ketuk "Unduh Laporan (PDF)" untuk mendapatkan ringkasan lengkap beserta rincian transaksinya.',
      ),
    ],
  ),
];
