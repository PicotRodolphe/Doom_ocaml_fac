open Segment
open Point
open Trigo
open Player
open Graphics


let taille = 500

let int_of_bool b = 
	if b then 1 else 0

let accroupir = ref false

let angle_vision = Options.fov

let fabs a =
	if a < 0. then -.a else a

let d_focale = int_of_float(float_of_int(taille/2)/. fabs (dtan (angle_vision/2 ))) 

(*Effectue une translation sur un segment par rapport à la position du joueur*)
let calcul_vecteur p s =
	Segment.new_segment (s.porig.x-p.pos.x) 
						(s.porig.y-p.pos.y)
						(s.pdest.x-p.pos.x) 
						(s.pdest.y-p.pos.y)

(*
	on effectue une rotation sur les segments pour les avoir en face du joueur

	les formules =
	xa' = xa * cos (-a) - ya * sin (-a)
	ya' = xa * sin (-a) + ya * cos (-a)
	xb' = xb * cos (-a) - yb * sin (-a)
	yb' = xb * sin (-a) + yb * cos (-a)
*)

let calcul_angle p s =
	Segment.new_segment 
		(int_of_float (float_of_int (s.porig.x) *. Trigo.dcos (-p.pa) -. float_of_int (s.porig.y) *. Trigo.dsin (-p.pa)))
		(int_of_float (float_of_int (s.porig.x) *. Trigo.dsin (-p.pa) +. float_of_int (s.porig.y) *. Trigo.dcos (-p.pa)))
		(int_of_float (float_of_int (s.pdest.x) *. Trigo.dcos (-p.pa) -. float_of_int (s.pdest.y) *. Trigo.dsin (-p.pa)))
		(int_of_float (float_of_int (s.pdest.x) *. Trigo.dsin (-p.pa) +. float_of_int (s.pdest.y) *. Trigo.dcos (-p.pa)))


let ata xo yo xd yd = 
	float_of_int(yd - yo) /. float_of_int(xd - xo)


let clipping s = 

	let xo = s.porig.x in
	let yo = s.porig.y in
	let xd = s.pdest.x in
	let yd = s.pdest.y in
	let angle_mur = ata xo yo xd yd in
(*on affiche pas un mur qui serait derriere le joueur, si il y a une partie du mur qui se trouve derriere,
nous créons un nouveau segment*)
	if xo < 1 && xd < 1 then None
	else if xo < 1 then Some(Segment.new_segment 1 (yo+int_of_float(float_of_int(1-xo)*. angle_mur)) xd yd ) 
	else if xd < 1 then Some(Segment.new_segment xo yo 1 (yd + int_of_float(float_of_int(1-xd)*. angle_mur)))
	else Some(s)

let distance xa ya xb yb =
	let xf = float_of_int xa in
	let yf = float_of_int xb in
	let tf = float_of_int xb in
	let zf = float_of_int yb in


	sqrt ((xf**2. -. tf**2. )+.(yf**2. -. zf**2. ))

(*
on calcule la correspondance entre la projection et la coordonnée x de l'affichage, 
ce qui revient à faire une fonction affine
*)
let calcul_p_x cmax c =
	let a = float_of_int (taille/2)/.float_of_int(-cmax) in 
	let b = float_of_int(taille/2) in
	int_of_float ( a *. float_of_int (c) +. b)

(*va afficher en 3D un segment*)
let passage_3d cmax xo yo xd yd co cd =

	let accroupissement = 
		int_of_bool (!accroupir) * 25 
	in
	let hauteur_yeux = (taille/2) + accroupissement in 

(*on fait la meme chose que pour x, on applique une simple fonction affine *)
	let calcul_p_y x y =
		let echelle = float_of_int(taille/4) in
		let rapport = float_of_int d_focale /. distance x y 0 0 in
		let calcul = int_of_float(echelle *. rapport)+hauteur_yeux in 
		calcul
	in

	let p_gauche = Point.new_point
	(calcul_p_x cmax co)
	(calcul_p_y xo yo)
	in
	let p_droite = Point.new_point
	(calcul_p_x cmax cd)
	(calcul_p_y xd yd) in 

	Graphics.set_color (Graphics.rgb 0 100 0);
	Graphics.fill_poly [|
		p_gauche.x,(hauteur_yeux-(p_droite.y-hauteur_yeux));
		p_gauche.x,p_droite.y;
		p_droite.x,p_gauche.y;
		p_droite.x,(hauteur_yeux-(p_gauche.y-hauteur_yeux))
	|];
	Graphics.set_color (Graphics.rgb 0 0 0);
	Graphics.draw_segments [|
		p_gauche.x,(hauteur_yeux-(p_droite.y-hauteur_yeux)),p_gauche.x,p_droite.y;
		p_droite.x,p_gauche.y,p_droite.x,(hauteur_yeux-(p_gauche.y-hauteur_yeux));
		p_gauche.x,(hauteur_yeux-(p_droite.y-hauteur_yeux)), p_droite.x,(hauteur_yeux-(p_gauche.y-hauteur_yeux));
		p_gauche.x,p_droite.y,p_droite.x,p_gauche.y;
	|]

let projection seg p =

	(*y' = ( y * d ) / x
	cette formule permet de connaitre la colonne sur l'ecran d'une extremité d'un segment
	 *)
	let project p =
		int_of_float(float_of_int (d_focale * p.y) /. float_of_int( p.x )) in

	let cmax = int_of_float (dtan (angle_vision/2) *. float_of_int d_focale) in
	let cmin = (-cmax) in 
	let c_p_orig = project seg.porig in
	let c_p_dest = project seg.pdest in

(*Si le segment à une partie en dehors du champ de vision du joueur, on affiche seulement le pan visible,
pour cela, on calcul le point d'intersection entre le champ de vision et le segment, ce que fait correction*)
	let correction point ctest = 

		if ctest < cmin then 
		let (nw_x,nw_y) = Trigo.point_intersection_droites seg.porig.x seg.porig.y seg.pdest.x seg.pdest.y 0 0 d_focale cmin in
		nw_x,nw_y,cmin
		else if ctest > cmax then 
		let (nw_x,nw_y) = Trigo.point_intersection_droites seg.porig.x seg.porig.y seg.pdest.x seg.pdest.y 0 0 d_focale cmax in
		nw_x,nw_y,cmax
		else point.x, point.y, ctest
	in

	match c_p_orig, c_p_dest with
	| a,b when a > cmax && b > cmax -> ()
	| a,b when a < cmin && b < cmin -> ()
	| a,b -> let (nw_x_orig,nw_y_orig,nw_c_p_orig) = correction seg.porig c_p_orig in
			let (nw_x_dest,nw_y_dest,nw_c_p_dest) = correction seg.pdest c_p_dest in 
			passage_3d cmax nw_x_orig nw_y_orig nw_x_dest nw_y_dest nw_c_p_dest nw_c_p_orig

let affiche_mp seg t =
	let emplacement = float_of_int (taille/6) in
	let xo = float_of_int seg.porig.x in
	let yo = float_of_int seg.porig.y in
	let xd = float_of_int seg.pdest.x in
	let yd = float_of_int seg.pdest.y in
	let tai = float_of_int t in
	Graphics.draw_segments [|
	int_of_float((xo *. emplacement /.tai )+. emplacement),
	int_of_float((yo *. emplacement /.tai )+. emplacement),
	int_of_float((xd *. emplacement /.tai )+. emplacement),
	int_of_float((yd *. emplacement /.tai )+. emplacement)|]

let affiche_match xa ya xb yb = 
	match xa,ya,xb,yb with
	| None,None,None,None -> ()
	| Some(x),Some(y),Some(z),Some(t) -> 
	Printf.printf "xa : %d ya : %d xb : %d yb : %d" x y z t
	| _,_,_,_ -> ()

let mini_map perso s =

	let emplacement = taille/6 in
	Graphics.draw_circle  emplacement  emplacement  emplacement;

	let seg = calcul_vecteur perso s in
	let dist_limite = 500 in 
	let dist1 = int_of_float(sqrt(float_of_int seg.porig.x**2. +. float_of_int seg.porig.y**2.)) in
	let dist2 = int_of_float(sqrt(float_of_int seg.pdest.x**2. +. float_of_int seg.pdest.y**2.)) in 

	match dist1, dist2 with
	| a,b when a < dist_limite && b < dist_limite -> affiche_mp seg dist_limite
	| a,b -> 
	Printf.printf "seg.porig.x = %d seg.porig.y = %d seg.pdest.x = %d seg.pdest.y = %d"
	seg.porig.x seg.porig.y seg.pdest.x seg.pdest.y ;
	let (xa,ya,xb,yb) = Trigo.points_intersection_droite_cercle
	seg.porig seg.pdest (float_of_int dist_limite) in
	affiche_match xa ya xb yb;
		match xa,ya,xb,yb with
		| None,None,None,None -> ()
		| Some(nxa),Some(nya),Some(nxb),Some(nyb) when a > dist_limite && b > dist_limite ->
		affiche_mp (Segment.new_segment nxa nya nxb nyb) dist_limite
		| Some(nxa),Some(nya),Some(nxb),Some(nyb) when a < dist_limite && b > dist_limite ->
		affiche_mp (Segment.new_segment nxa nya seg.pdest.x seg.pdest.y) dist_limite
		| Some(nxa),Some(nya),Some(nxb),Some(nyb) when a < dist_limite && b > dist_limite ->
		affiche_mp (Segment.new_segment seg.porig.x seg.porig.y nxb nyb) dist_limite
		| _,_,_,_ -> () (*n'arrive jamais *) 


let affiche p = fun s -> 

	let nw_seg = calcul_angle p (calcul_vecteur p s) in 
	let clip = clipping nw_seg in

	match clip with
	| None -> ()
	| Some(seg) -> projection seg p

let clear_graph () = 
	Graphics.set_color (Graphics.rgb 40 40 40);
	Graphics.fill_poly[|
	0,0;
	0,taille/2;
	taille,taille/2;
	taille,0;
	|];
	Graphics.set_color (Graphics.rgb 75 0 0);
	Graphics.fill_poly[|
	0,taille;
	0,taille/2;
	taille,taille/2;
	taille,taille;
	|]

let display bsp p = 

	accroupir := p.accroupi;
	clear_graph ();
	Bsp.rev_parse (affiche p) bsp p.pos;
	Bsp.iter  (mini_map p) bsp;
	synchronize ()