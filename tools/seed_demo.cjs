// Local preview only: every request is pinned to the demo Firebase emulators.
// Existing documents and user edits are preserved when this script is rerun.
const fs = require('node:fs');
const path = require('node:path');

const project = 'demo-pawpals';
const authBase = 'http://127.0.0.1:9199';
const storeBase = `http://127.0.0.1:8180/v1/projects/${project}/databases/(default)/documents`;
const email = 'demo@pawpals.test';
const password = 'PawPals123!'; // Only usable against the local Auth emulator.

async function request(url, body, method = 'POST') {
  const response = await fetch(url, {
    method,
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(30000),
  });
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(`${response.status}: ${data.error?.message || response.statusText}`);
    error.status = response.status;
    throw error;
  }
  return data;
}

function value(item) {
  if (item === null) return { nullValue: null };
  if (item instanceof Date) return { timestampValue: item.toISOString() };
  if (typeof item === 'boolean') return { booleanValue: item };
  if (typeof item === 'number') return Number.isInteger(item)
    ? { integerValue: String(item) } : { doubleValue: item };
  if (typeof item === 'string') return { stringValue: item };
  if (Array.isArray(item)) return { arrayValue: { values: item.map(value) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(item).map(([key, entry]) => [key, value(entry)])) } };
}

async function create(documentPath, data) {
  const fields = Object.fromEntries(Object.entries(data).map(([key, entry]) => [key, value(entry)]));
  try {
    await request(`${storeBase}/${documentPath}?currentDocument.exists=false`, { fields }, 'PATCH');
  } catch (error) {
    if (error.status !== 409) throw error;
  }
}

async function main() {
  const accounts = await request(`${authBase}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`, { email: [email] });
  let uid = accounts.users?.find(user => user.email === email)?.localId;
  if (!uid) {
    const account = await request(`${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-pawpals-key`, {
      email, password, returnSecureToken: true,
    });
    uid = account.localId;
  }
  await request(`${authBase}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`, {
    localId: uid, emailVerified: true, displayName: 'Hoàng Demo',
    customAttributes: JSON.stringify({ admin: true }),
  });
  await create(`users/${uid}`, {
    uid, email, displayName: 'Hoàng Demo', phoneNumber: '',
    address: 'Địa chỉ giao hàng mẫu – chỉ dùng thử', avatarUrl: null, membershipLevel: 'STANDARD',
  });

  async function member(address, displayName) {
    const result = await request(`${authBase}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`, { email: [address] });
    let memberUid = result.users?.find(user => user.email === address)?.localId;
    if (!memberUid) {
      const account = await request(`${authBase}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-pawpals-key`, {
        email: address, password, returnSecureToken: true,
      });
      memberUid = account.localId;
      await request(`${authBase}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`, {
        localId: memberUid, emailVerified: true, displayName,
      });
    }
    await create(`users/${memberUid}`, {uid:memberUid,email:address,displayName,phoneNumber:'',
      address:'',avatarUrl:null,membershipLevel:'STANDARD'});
    return memberUid;
  }
  await member('member@pawpals.test', 'Người dùng Demo');
  const applicantUid = await member('applicant@pawpals.test', 'Nhân viên Demo');
  await create(`admin_requests/${applicantUid}`, {
    uid:applicantUid,email:'applicant@pawpals.test',displayName:'Nhân viên Demo',
    reason:'Tôi phụ trách cập nhật sản phẩm và xử lý đơn hàng của cửa hàng.',
    status:'pending',createdAt:new Date(),updatedAt:new Date(),reviewedAt:null,reviewedBy:null,reviewNote:'',
  });

  const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, 'catalog.json'), 'utf8'));
  const extras = [
    ['demo_07', 'Bát ăn chống trượt', 'ACCESSORY', 'ALL', 75000, 95000, 42],
    ['demo_08', 'Dây dắt đi dạo 1,5m', 'ACCESSORY', 'DOG', 129000, 159000, 30],
    ['demo_09', 'Cần câu lông vũ cho mèo', 'TOY', 'CAT', 59000, 79000, 55],
    ['demo_10', 'Bóng cao su nhiều màu', 'TOY', 'DOG', 49000, 65000, 70],
    ['demo_11', 'Khăn lau thú cưng', 'HYGIENE', 'ALL', 39000, 49000, 100],
    ['demo_12', 'Túi vận chuyển thú cưng', 'ACCESSORY', 'ALL', 329000, 399000, 18],
  ].map(([id, name, category, petTarget, price, originalPrice, stock]) => ({
    id, name, category, petTarget, price, originalPrice, stock,
    discountPercent: Math.round((1 - price / originalPrice) * 100),
    rating: 4.8, reviewCount: 25, imageUrl: '', weight: 'Mẫu demo',
    description: 'Sản phẩm minh họa để thử tìm kiếm, giỏ hàng và đặt hàng trong môi trường demo.',
    isFeatured: true, isActive: true,
  }));
  for (const product of [...catalog, ...extras]) {
    await create(`products/${product.id}`, { ...product, isActive: true });
  }

  const pets = [
    { id: 1001, name: 'Bông', species: 'Mèo', breed: 'Anh lông ngắn', gender: 'Cái', birth_date: '2024-03-20', weight: 4.2 },
    { id: 1002, name: 'Milo', species: 'Chó', breed: 'Golden Retriever', gender: 'Đực', birth_date: '2023-06-15', weight: 24.5 },
    { id: 1003, name: 'Mochi', species: 'Chó', breed: 'Poodle', gender: 'Cái', birth_date: '2025-01-10', weight: 3.8 },
  ];
  for (const pet of pets) {
    await create(`users/${uid}/pets/${pet.id}`, {
      ...pet, server_id: String(pet.id), microchip_id: null,
      avatar_path: null, avatar_cloud_url: null, is_synced: 1,
    });
  }
  const date = (daysAgo) => {
    const day = new Date(Date.now() + 7 * 60 * 60 * 1000 - daysAgo * 86400000);
    return day.toISOString().slice(0, 10);
  };
  const records = [
    [2001, 1001, 'CHECKUP', 'Khám định kỳ của Bông', 7, 200000],
    [2002, 1001, 'VACCINE', 'Lịch sử tiêm phòng của Bông', 30, 250000],
    [2003, 1002, 'CHECKUP', 'Kiểm tra sức khỏe của Milo', 3, 300000],
    [2004, 1002, 'DEWORMING', 'Lịch sử tẩy giun của Milo', 20, 120000],
    [2005, 1003, 'CHECKUP', 'Khám định kỳ của Mochi', 10, 180000],
    [2006, 1003, 'VACCINE', 'Lịch sử tiêm phòng của Mochi', 45, 250000],
  ];
  for (const [id, pet_id, record_type, title, daysAgo, cost] of records) {
    await create(`users/${uid}/health_records/${id}`, {
      id, pet_id, record_type, title, administered_date: date(daysAgo),
      next_due_date: null, veterinarian: 'Bác sĩ minh họa', clinic_name: 'Phòng khám DEMO',
      notes: 'Bản ghi minh họa giao diện, không phải hồ sơ hoặc chỉ định y tế thực tế.', cost,
    });
  }
  const reminders = [
    [3001, 1001, 'Cho Bông ăn sáng', '07:30'],
    [3002, 1002, 'Dắt Milo đi dạo', '08:00'],
    [3003, 1003, 'Chải lông cho Mochi', '17:30'],
    [3004, 1001, 'Vệ sinh khay cát của Bông', '18:00'],
    [3005, 1002, 'Cho Milo ăn tối', '19:00'],
  ];
  for (const [id, pet_id, title, reminder_time] of reminders) {
    await create(`users/${uid}/reminders/${id}`, {
      id, pet_id, title, reminder_time, repeat_interval: 'DAILY', notification_id: id, is_active: 1,
    });
  }
  for (let index = 1; index <= 3; index++) {
    const id = `demo_clinic_${index}`;
    await create(`clinics/${id}`, {
      id, name: `DEMO – Phòng khám thú cưng ${index}`,
      address: 'Địa chỉ mô phỏng, không phải cơ sở khám thực tế',
      latitude: 10.8, longitude: 106.7, phone: '', rating: 4.8,
      isOpen24_7: false, openHours: '08:00 - 20:00 (minh họa)',
      services: ['Khám tổng quát (demo)', 'Chăm sóc thú cưng (demo)'],
    });
  }
  const articles = [
    ['Hồ sơ riêng cho từng người bạn nhỏ', 'Hướng dẫn', 'Thêm tên, giống, ngày sinh và cân nặng để dễ quản lý thú cưng.',
      'Mở tab Thú cưng rồi chọn Thêm thú cưng. Điền thông tin và lưu hồ sơ. Bạn có thể mở từng hồ sơ để xem sổ sức khỏe và lịch nhắc.\n\nĐây là nội dung minh họa cho bản demo PawPals.'],
    ['Sắp xếp lịch chăm sóc mỗi ngày', 'Tiện ích', 'Thử lịch nhắc ăn uống, đi dạo và chải lông trong ứng dụng.',
      'Mở hồ sơ thú cưng, thêm một lịch nhắc và chọn giờ phù hợp. Bạn có thể bật hoặc tắt từng lịch. Cho phép thông báo trên thiết bị để thử tính năng nhắc lịch.\n\nCác lịch trong bản demo chỉ là dữ liệu minh họa.'],
    ['Khám phá cửa hàng PawPals', 'Cửa hàng', 'Tìm sản phẩm, thêm vào giỏ và thử mã PAWPALS10.',
      'Mở tab Cửa hàng, chọn danh mục hoặc tìm theo tên. Thêm sản phẩm vào giỏ để xem tổng tiền. Mã PAWPALS10 giảm 10% tiền hàng.\n\nMôi trường demo chỉ tạo đơn thử trong Firebase Emulator; không phát sinh giao dịch hoặc giao hàng thực tế.'],
  ];
  for (const [index, [title, category, summary, content]] of articles.entries()) {
    const id = `demo_article_${index + 1}`;
    await create(`articles/${id}`, {
      id, title, category, summary, content, author: 'PawPals Demo',
      publishedAt: date(index), thumbnailUrl: '', readTimeMinutes: 2,
    });
  }
  console.log('Local demo ready: 3 pets, 6 health records, 5 reminders, 12 products, 3 demo clinics, 3 articles.');
  console.log(`Login: ${email} / ${password} (local emulator only; administrator enabled).`);
  console.log(`Member login: member@pawpals.test / ${password}; applicant@pawpals.test has a sample request.`);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
