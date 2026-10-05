// Backend handoffs only: demo data, seeded offer, manually delivered trigger.
// This does not simulate device Auth/rules, push, provider payment or tax policy.
const assert=require('node:assert/strict');
if(!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST||''))throw Error('Loopback emulator required');
process.env.GCLOUD_PROJECT='demo-foundation-connected-cod';
require('axios').get=async()=>{throw Error('External provider transport forbidden');};
const admin=require('firebase-admin');admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore();const {Timestamp}=require('firebase-admin/firestore');
const fft=require('firebase-functions-test')({projectId:process.env.GCLOUD_PROJECT});
const create=fft.wrap(require('../lib/customer/createOrder').createOrder);
const sell=fft.wrap(require('../lib/seller/sellerTransitionOrder').sellerTransitionOrder);
const confirm=fft.wrap(require('../lib/customer/confirmDelivery').confirmDelivery);
const sellerPayout=fft.wrap(require('../lib/customer/sellerNotifications').calculateSellerPayout);
const D=require('../lib/delivery/dispatchCallables'), S=require('../lib/delivery/riderSteps'), M=require('../lib/delivery/riderMoney');
const customer={uid:'fixture_journey_customer',token:{}}, seller={uid:'fixture_journey_seller',token:{seller:true}}, rider='fixture_journey_rider';
const get=async p=>(await db.doc(p).get()).data();let checks=0;
function check(label,body){body();checks++;console.log(`PASS ${label}`);}
const address={name:'Fixture customer',phone:'9999999999',addressLine1:'Fixture',city:'Chennai',state:'TN',zipcode:'600001',country:'India',latitude:13.081,longitude:80.271};
const pickup={lat:13.08,lng:80.27};
(async()=>{
 await db.doc(`users/${customer.uid}`).set({profileCompleted:true});
 await db.doc(`sellers/${seller.uid}`).set({status:'approved',storeLat:pickup.lat,storeLng:pickup.lng});
 await db.doc('products/fixture_journey_product').set({name:'Fixture product',sellerId:seller.uid,salePrice:100,stock:10,images:[]});
 await db.doc('settings/commission').set({defaultRate:10,categoryRates:{}});
 await db.doc(`delivery_partners/${rider}`).set({name:'Fixture rider',status:'approved',isOnline:true,currentLat:pickup.lat,currentLng:pickup.lng,lastLocationUpdate:Timestamp.now(),upiId:'fixture@example.invalid'});
 const data={paymentMethod:'cod',checkoutRequestId:'fixture_connected_checkout',items:[{productId:'fixture_journey_product',quantity:2}],orderMode:'B2C',deliveryAddress:address,deliveryCharge:0,tax:0};
 const result=await create({data,auth:customer});const id=result.orders[0].orderId;
 check('customer order derives price and reserves stock',()=>{assert.equal(result.orders.length,1);assert.equal(result.orders[0].total,200);});
 assert.equal((await get('products/fixture_journey_product')).stock,8);checks++;console.log('PASS exact stock reservation');
 const retry=await create({data,auth:customer});check('customer retry returns same order',()=>assert.equal(retry.orders[0].orderId,id));
 assert.equal((await get('products/fixture_journey_product')).stock,8);checks++;console.log('PASS retry does not reserve stock twice');
 await assert.rejects(sell({data:{orderId:id,action:'accept'},auth:{uid:'fixture_other_seller',token:{seller:true}}}),e=>e.code==='permission-denied');checks++;console.log('PASS other seller refused');
 for(const [action,status] of [['accept','confirmed'],['pack','processing'],['ready','ready_for_pickup']]){await sell({data:{orderId:id,action},auth:seller});assert.equal((await get(`orders/${id}`)).orderStatus,status);checks++;console.log(`PASS seller ${action}`);}
 const now=Date.now();await db.doc(`delivery_requests/${id}_${rider}`).set({orderId:id,riderId:rider,status:'offered',expiresAt:Timestamp.fromMillis(now+30000)});
 const accepted=await D.acceptOfferCore(db,rider,id,now);check('assigned rider accepts offered ready order',()=>assert.equal(accepted.kind,'accepted'));
 const acceptedRetry=await D.acceptOfferCore(db,rider,id,now);check('accept retry preserves assignment',()=>assert.equal(acceptedRetry.alreadyAccepted,true));
 assert.equal((await S.advanceStepCore(db,'fixture_other_rider',id,'picked_up',null,now)).reason,'not_assigned');checks++;console.log('PASS other rider cannot advance');
 assert.equal((await S.advanceStepCore(db,rider,id,'out_for_delivery',null,now)).reason,'bad_transition');checks++;console.log('PASS pickup cannot be skipped');
 const fix={lat:pickup.lat,lng:pickup.lng,accuracy:5,isMocked:false};
 for(const step of ['arrived_at_store','picked_up','out_for_delivery']){assert.equal((await S.advanceStepCore(db,rider,id,step,fix,Date.now())).kind,'advanced');assert.equal((await S.advanceStepCore(db,rider,id,step,fix,Date.now())).kind,'already');checks++;console.log(`PASS rider ${step} and retry`);}
 const before=await get(`orders/${id}`), secret=await get(`orders/${id}/secrets/delivery`);
 const code=secret.code;
 assert.equal(typeof code,'string');
 await assert.rejects(confirm({data:{orderId:id,code},auth:{uid:'fixture_other_rider',token:{}}}),e=>e.code==='permission-denied');checks++;console.log('PASS other rider cannot confirm');
 const confirmed=await confirm({data:{orderId:id,code},auth:{uid:rider,token:{}}});assert.equal(confirmed.alreadyDelivered,false);checks++;console.log('PASS assigned rider confirms private code');
 assert.equal((await confirm({data:{orderId:id,code},auth:{uid:rider,token:{}}})).alreadyDelivered,true);checks++;console.log('PASS delivery retry succeeds once');
 const after=await get(`orders/${id}`);
 const change=()=>fft.makeChange(fft.firestore.makeDocumentSnapshot(before,`orders/${id}`),fft.firestore.makeDocumentSnapshot(after,`orders/${id}`));
 await Promise.all([sellerPayout(change(),{params:{orderId:id}}),sellerPayout(change(),{params:{orderId:id}})]);
 const payouts=await db.collection('seller_payouts').where('orderId','==',id).get();assert.equal(payouts.size,1);assert.equal(payouts.docs[0].data().grossAmount,200);assert.equal(payouts.docs[0].data().netAmount,180);checks++;console.log('PASS seller trigger replay creates one fixture-rate payout');
 const earned=await M.recordDeliveryEarningCore(db,id,Date.now());assert.equal(earned.kind,'created');assert.equal(earned.cod,200);assert.equal((await M.recordDeliveryEarningCore(db,id,Date.now())).kind,'already');checks++;console.log('PASS rider earning and COD collection happen once');
 const deposit=await M.recordCashDepositCore(db,'fixture_admin',rider,200,'FIXTURE_RECEIPT',Date.now(),'fixture_connected_deposit');assert.equal(deposit.kind,'recorded');assert.equal(deposit.cashHeld,0);assert.equal((await M.recordCashDepositCore(db,'fixture_admin',rider,200,'FIXTURE_RECEIPT',Date.now(),'fixture_connected_deposit')).already,true);checks++;console.log('PASS cash handover replay happens once');
 const statement=await M.buildStatementCore(db,rider,Date.now()+14*86400000);assert.equal(statement.kind,'created');assert.equal(statement.status,'pending');assert.equal(statement.amount,earned.total);assert.equal((await M.buildStatementCore(db,rider,Date.now()+14*86400000)).kind,'exists');checks++;console.log('PASS weekly statement covers unsettled earning once');
 assert.equal((await M.markPayoutPaidCore(db,'fixture_admin',statement.id,'FIXTURE_PAYOUT','upi',Date.now())).kind,'paid');assert.equal((await M.markPayoutPaidCore(db,'fixture_admin',statement.id,'FIXTURE_PAYOUT','upi',Date.now())).kind,'already');checks++;console.log('PASS payout record replay preserves chosen destination');
 assert.equal((await get(`rider_accounts/${rider}`)).earningsUnsettledPaise,0);assert.equal((await get('products/fixture_journey_product')).stock,8);checks++;console.log('PASS final accounting and stock remain consistent');
 console.log(`RESULT ${checks} connected backend checks passed`);fft.cleanup();await db.terminate();
})().catch(async e=>{console.error(`FAIL connected journey: ${e.stack}`);fft.cleanup();await db.terminate();process.exitCode=1;});
