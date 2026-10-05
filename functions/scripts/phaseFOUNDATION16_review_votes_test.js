// Demo-only product review voting rules regression. No Functions/provider execution.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc } = require('firebase/firestore');
async function main() {
 const env=await initializeTestEnvironment({projectId:'demo-agrimore-review-votes',firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8')}});
 let passed=0,failed=0;
 const check=async(name,fn)=>{try{await fn();passed++;console.log('PASS '+name);}catch(e){failed++;console.log('FAIL '+name+': '+e.message);}};
 const user=uid=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
 const ref=(uid,id)=>doc(user(uid),'products/p/reviews/'+id);
 const base={userId:'author',productId:'p',rating:4,comment:'Original',helpfulUsers:['other'],unhelpfulUsers:['critic'],helpfulCount:1,unhelpfulCount:1,sellerReply:{text:'Reply'},sellerId:'seller',productName:'Product'};
 const fixture=async(id,overrides={})=>env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'products/p/reviews/'+id),{...base,...overrides}));
 const vote=(yes,no)=>({helpfulUsers:yes,unhelpfulUsers:no,helpfulCount:yes.length,unhelpfulCount:no.length});
 const run=async(name,actor,patch,allowed,overrides={})=>{await fixture(name,overrides);await check(name,()=> (allowed?assertSucceeds:assertFails)(updateDoc(ref(actor,name),patch)));};
 try {
  await fixture('read');await check('public_read',()=>assertSucceeds(getDoc(ref(null,'read'))));
  await run('reader_add_helpful','reader',vote(['other','reader'],['critic']),true);
  await run('reader_add_unhelpful','reader',vote(['other'],['critic','reader']),true);
  await run('reader_remove_helpful','reader',vote(['other'],['critic']),true,{helpfulUsers:['other','reader'],helpfulCount:2});
  await run('reader_switch_to_unhelpful','reader',vote(['other'],['critic','reader']),true,{helpfulUsers:['other','reader'],helpfulCount:2});
  await run('reader_switch_to_helpful','reader',vote(['other','reader'],['critic']),true,{unhelpfulUsers:['critic','reader'],unhelpfulCount:2});
  await run('reader_remove_unhelpful','reader',vote(['other'],['critic']),true,{unhelpfulUsers:['critic','reader'],unhelpfulCount:2});
  await run('author_own_vote','author',vote(['other','author'],['critic']),true);
  await run('anonymous_vote',null,vote(['other','anonymous'],['critic']),false);
  await run('cannot_add_other_voter','reader',vote(['other','invented'],['critic']),false);
  await run('author_cannot_forge_votes','author',vote(['invented'],[]),false);
  await run('author_cannot_forge_count','author',{helpfulCount:999},false);
  await run('cannot_remove_other_voter','reader',vote([],['critic']),false);
  await run('cannot_vote_both','reader',vote(['other','reader'],['critic','reader']),false);
  await run('cannot_duplicate_voter','reader',vote(['other','reader','reader'],['critic']),false);
  await run('cannot_lie_count','reader',{...vote(['other','reader'],['critic']),helpfulCount:999},false);
  await run('cannot_change_comment_with_vote','reader',{...vote(['other','reader'],['critic']),comment:'Forged'},false);
  await run('author_cannot_mix_content_vote','author',{...vote(['other','author'],['critic']),comment:'Changed'},false);
  await run('cannot_change_author','reader',{...vote(['other','reader'],['critic']),userId:'reader'},false);
  await run('cannot_change_server_reply','reader',{...vote(['other','reader'],['critic']),sellerReply:{text:'Forged'}},false);
  await run('cannot_change_rating_with_vote','reader',{...vote(['other','reader'],['critic']),rating:5},false);
  await run('author_content_edit','author',{rating:3,comment:'Updated'},true);
  await run('nonauthor_content_edit','reader',{comment:'Forged'},false);
  await run('author_server_stamp_edit','author',{sellerId:'different'},false);
  await run('cannot_use_fractional_count','reader',{...vote(['other','reader'],['critic']),helpfulCount:2.5},false);
  await run('cannot_use_wrong_array_type','reader',{helpfulUsers:'reader',helpfulCount:1},false);
  await run('invalid_existing_array_fails_closed','reader',vote(['reader'],['critic']),false,{helpfulUsers:null,helpfulCount:0});
  await run('invalid_existing_duplicate_fails_closed','reader',vote(['other','reader'],['critic']),false,{helpfulUsers:['other','other'],helpfulCount:2});
  await run('invalid_existing_count_fails_closed','reader',vote(['other','reader'],['critic']),false,{helpfulCount:500});
  await run('invalid_existing_overlap_fails_closed','reader',vote(['other','reader'],['critic']),false,{unhelpfulUsers:['other'],unhelpfulCount:1});
  await fixture('legacy');await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'products/p/reviews/legacy'),{userId:'author',productId:'p',rating:4}));
  await check('legacy_absent_empty_fields_self_vote',()=>assertSucceeds(updateDoc(ref('reader','legacy'),vote(['reader'],[]))));
  for(const [name,data,allowed] of [
   ['create_without_vote_fields',{userId:'new',productId:'p',rating:4},true],
   ['create_with_empty_votes',{userId:'new',productId:'p',rating:4,...vote([],[])},true],
   ['create_with_forged_votes',{userId:'new',productId:'p',rating:4,...vote(['invented'],[])},false],
   ['create_with_forged_count',{userId:'new',productId:'p',rating:4,helpfulCount:500},false],
   ['create_with_wrong_vote_type',{userId:'new',productId:'p',rating:4,helpfulUsers:'new'},false]]){
    await check(name,()=> (allowed?assertSucceeds:assertFails)(setDoc(ref('new',name),data)));
  }
  // Old clients cannot overwrite a vote committed by another reader.
  await fixture('concurrent');await check('first_reader_vote',()=>assertSucceeds(updateDoc(ref('a','concurrent'),vote(['other','a'],['critic']))));
  await check('stale_reader_overwrite_denied',()=>assertFails(updateDoc(ref('b','concurrent'),vote(['other','b'],['critic']))));
  await check('fresh_second_reader_vote',()=>assertSucceeds(updateDoc(ref('b','concurrent'),vote(['other','a','b'],['critic']))));
  await check('both_votes_preserved',async()=>{const s=await getDoc(ref(null,'concurrent'));if(s.data().helpfulCount!==3)throw Error('Votes lost');});
  console.log(`SUMMARY ${passed} passed ${failed} failed`);if(failed)process.exitCode=1;
 }finally{await env.cleanup();}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
