# AgentMark — Service Registry & Endorsement Ledger for Agent ID Holders

**Nama proyek:** AgentMark (netral — tanpa brand Binance/BNB, sesuai aturan)
**Tagline:** *The phone book and reputation ledger of the agent economy — every entry is an Agent ID.*
**Stack:** 1 kontrak Solidity di BNB Chain + frontend statis (HTML/JS, Netlify) yang membaca kontrak via RPC publik. Tanpa backend, tanpa server, tanpa penyimpanan sesi siapa pun.

---

## 1. Masalah

Ekosistem Agentic Wallet tumbuh cepat (108rb+ Agent ID sudah diklaim menurut data ekosistem), tapi tidak ada cara on-chain untuk:

1. **Menemukan** agent lain menawarkan layanan apa ("siapa yang bisa riset data? siapa yang bisa audit kontrak?").
2. **Mempercayai** mereka — alamat wallet anonim tidak punya riwayat; sybil bisa membuat 1.000 wallet dalam semenit.

Agent ID menyelesaikan separuh masalah identitas (satu manusia terverifikasi Binance = satu Agent ID, non-transferable), tapi identitas saja tidak cukup: belum ada registry layanan + reputasi yang **menempel pada Agent ID itu sendiri**.

## 2. Konsep

AgentMark adalah registry layanan + buku endorsement yang **seluruhnya dikunci oleh Agent ID**:

- Hanya pemegang Agent ID yang bisa **mendaftarkan layanan** (satu listing per Agent ID).
- Listing terikat ke **tokenId Agent ID** si pendaftar — bukan sekadar alamat. Kontrak memverifikasi `ownerOf(tokenId) == msg.sender` saat registrasi.
- Hanya pemegang Agent ID yang bisa **memberi endorsement**, dan hanya **kepada Agent ID lain**. Satu endorsement per (pemberi, penerima, tag keahlian) — tidak bisa di-spam.
- Skor reputasi sebuah Agent ID = jumlah endorsement unik yang diterimanya, terpilah per tag keahlian. Semua terbaca on-chain oleh siapa pun, gratis.

Karena Agent ID bersifat satu-per-manusia dan non-transferable, endorsement di AgentMark **tidak bisa difarming dengan wallet sybil** — inilah kedalaman pemakaian Agent ID-nya: Agent ID bukan tempelan login, melainkan akar identitas untuk registrasi, endorsement, dan reputasi sekaligus.

## 3. Alur pengguna

1. **Buka situs** → situs membaca kontrak via RPC publik (tanpa login, tanpa pairing QR — dilarang oleh aturan, dan memang tidak dipakai).
2. **"Cek Agent ID saya"** → user mengetik nama `label.ai`-nya atau alamatnya; frontend menghitung tokenId = `keccak256(label)` dan memanggil `balanceOf`/`ownerOf` untuk membuktikan kepemilikan. Nama ditampilkan dari metadata SPACE ID.
3. **Daftarkan layanan** → dari Agentic Wallet-nya (via skill `baw` atau wallet apa pun), user memanggil `registerService(tokenId, category, metadataURI)`. Kontrak menolak bila `balanceOf == 0` atau `ownerOf(tokenId) != msg.sender`. Listing langsung tampil di direktori.
4. **Jelajahi direktori** → semua listing + skor endorsement terbaca dari event & view functions; filter per kategori/tag.
5. **Beri endorsement** → setelah memakai jasa agent lain, pemegang Agent ID memanggil `endorse(targetTokenId, skillTag)`. Kontrak menolak self-endorsement dan endorsement ganda.
6. **Profil agent** → halaman per-Agent-ID: nama `.ai`, layanan, daftar endorsement masuk (siapa memberi, tag apa) — semua dari data on-chain.

## 4. Kontrak — `AgentMarkRegistry.sol`

Satu kontrak, tanpa token, tanpa dana, tanpa admin:

| Fungsi | Sifat | Aturan Agent ID |
|---|---|---|
| `registerService(uint256 tokenId, bytes32 category, string metadataURI)` | tulis | `balanceOf(msg.sender) > 0` DAN `ownerOf(tokenId) == msg.sender`; 1 listing aktif per tokenId; bisa diperbarui pemiliknya |
| `removeService()` | tulis | hanya pemilik listing (berdasarkan tokenId terdaftar milik msg.sender) |
| `endorse(uint256 targetTokenId, bytes32 skillTag)` | tulis | pemberi wajib pemegang Agent ID; `ownerOf(targetTokenId)` harus ada & ≠ msg.sender; unik per (pemberi, target, tag) |
| `hasAgentId(address)` | baca | `balanceOf > 0` |
| `listingOf(uint256 tokenId)` / `listingByOwner(address)` | baca | data listing |
| `endorsementCount(uint256 tokenId)` / `endorsementCountByTag(tokenId, tag)` | baca | skor reputasi |
| `totalListings()` / `totalEndorsements()` | baca | statistik untuk frontend |

**Izin owner — dinyatakan terbuka (syarat hackathon):** kontrak **tidak punya owner/admin sama sekali**. Tidak ada fungsi mint, pajak, pause, freeze, atau penarikan dana. Semua fungsi tulis `nonpayable` — kontrak tidak pernah menerima/menyimpan BNB atau token user. Alamat kontrak Agent ID dikunci sebagai `immutable` saat deploy. Satu-satunya hal yang tidak bisa diubah siapa pun setelah deploy: aturan mainnya.

## 5. Bagaimana Agent ID dipakai di SETIAP langkah (kedalaman integrasi)

| Langkah | Pemakaian Agent ID |
|---|---|
| Identitas | tokenId (labelhash) adalah kunci utama listing & reputasi — bukan alamat mentah |
| Registrasi | gate `balanceOf > 0` + bukti `ownerOf(tokenId) == msg.sender` |
| Endorsement | pemberi & penerima dua-duanya wajib Agent ID terverifikasi on-chain |
| Anti-sybil | 1 manusia = 1 Agent ID (soulbound) ⇒ 1 listing, endorsement tidak bisa digandakan identitas palsu |
| Tampilan | nama `.ai` dari metadata SPACE ID (`tokenURI`) untuk profil manusiawi |
| Penemuan | direktori bisa dicari per nama `.ai`, kategori, dan skor endorsement |

## 6. Rencana mencapai ≥30 alamat Agent ID berinteraksi (jalur organik SAH)

Syarat Innovation Award: ≥30 alamat Agent ID berinteraksi dengan kontrak selama periode submisi (s/d 9 Des 2026 15:00 WIB). Kami hanya mengendalikan 1 Agent ID (arsyil4) — sisanya harus pengguna nyata. Rencana:

1. **Halaman skill untuk agent lain** (`skill.md` publik, pola yang terbukti di ekosistem ini): instruksi satu pesan yang bisa ditempel pemilik Agentic Wallet ke agent-nya — "daftarkan layananmu di AgentMark" — agent mereka mengeksekusi via `baw` dengan konfirmasi pemiliknya sendiri. Registrasi = 1 transaksi gas-saja (±0,0001 BNB), tanpa biaya ke kami.
2. **Endorsement timbal-balik yang tulus antar peserta hackathon:** hubungi tim peserta lain (direktori submisi + komunitas BNB Chain) — tawarkan: kami daftarkan + endorse layanan nyata mereka, mereka mencoba AgentMark dan endorse balik bila layanannya memang ada. Bukan barter suara otomatis — endorsement tetap pernyataan reputasi asli.
3. **Konten organik:** thread/dokumentasi publik tentang cara integrasi Agent ID (isi RESEARCH.md kami memang berguna bagi builder lain) → mengundang builder Agent ID lain mencoba registry.
4. **Nilai guna nyata sejak hari pertama:** direktori bisa dipakai peserta hackathon lain untuk menemukan kolaborator (riset, desain, audit) — alasan asli untuk mendaftar, bukan sekadar membantu kami.

**Yang TIDAK akan dilakukan** (diskualifikasi): registrasi massal, sybil, membeli interaksi, atau mengarahkan wallet non-Agent-ID untuk berpura-pura berinteraksi. Bila 30 tidak tercapai secara organik, itu dilaporkan apa adanya — produknya tetap live dan memenuhi syarat teknis lain.

## 7. Jadwal bangun (≤5 hari)

- Hari 1: kontrak + test lokal (SELESAI di Fase 1 ini) + estimasi gas.
- Hari 2: deploy BSC + verifikasi source di BscScan (butuh persetujuan pengeluaran gas dari Tian).
- Hari 3: frontend statis (direktori, profil, cek Agent ID) → Netlify.
- Hari 4: halaman skill.md + uji end-to-end memakai arsyil4 (registrasi + endorsement pertama).
- Hari 5: outreach organik peserta lain + submisi sebelum 9 Des.
