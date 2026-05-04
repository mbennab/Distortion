using Godot;
using System;
using System.Threading;

public partial class TimeAunote : CharacterBody2D{
	
	private AnimatedSprite2D timeAunoteAnimation;  // animation du time-aunote
	private CollisionShape2D timeAunoteCollision;  // collisions du personnage
	private Godot.Timer timerAttente;
	
	// Called when the node enters the scene tree for the first time.
	public override void _Ready(){
		// charge et initialise le module animation
		Hide();
		timeAunoteAnimation = GetNode<AnimatedSprite2D>("animation");
		timeAunoteAnimation.FlipH = false;
		timeAunoteAnimation.FlipV = false;
		timeAunoteAnimation.Play();
		// charge et initialise le module collision
		timeAunoteCollision = GetNode<CollisionShape2D>("collision");
		timeAunoteCollision.Disabled = true;
		// charge le timer d'animation d'attente
		timerAttente = GetNode<Godot.Timer>("timerAttente");
		timerAttente.Start();
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta){

	}
	
	// le timeAunote est positionne a sa place de depart et est affiche
	public void apparition(Vector2 position){
		// active l'animation REPOS du personnage principal
		timeAunoteAnimation.Animation = "repos";
		// le met en position
		Position = position;
		// affiche le personnage
		Show();
		// active les collisions avec les autres corps
		timeAunoteCollision.Disabled = false;
	}
	
	public void animation(Vector2 mouvement){
		if (mouvement == Vector2.Zero){
			if (timerAttente.IsStopped()) {
				timeAunoteAnimation.Animation = "attente";
			} else {
				timeAunoteAnimation.Animation = "repos";
			}
			return;
		}
		// animation de deplacement (vertical a la priorite pour l'animation)
		if (mouvement.X != 0) {
			timeAunoteAnimation.Animation = "marche_droite";
			if (mouvement.X > 0)
				timeAunoteAnimation.FlipH = false;
			else
				timeAunoteAnimation.FlipH = true;
		}
		if (mouvement.Y != 0) {
			if (mouvement.Y > 0) {
				timeAunoteAnimation.Animation = "marche_bas";
			} else {
				timeAunoteAnimation.Animation = "marche_haut";
			}
		} 
		//redemarre le timer pour l'animation d'attente
		timerAttente.Start();
	}
	
}
